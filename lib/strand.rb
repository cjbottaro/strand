require "fiber"
require "eventmachine"
require "strand/condition_variable"
require "strand/queue"
require "strand/mutex"

class Strand

  @@strands = {}

  # The strand's underlying fiber.
  attr_reader :fiber

  # Return an array of all Strands that are alive.
  def self.list
    @@strands.values
  end

  # Get the currently running strand.  Primarily used to access "strand local" variables.
  def self.current
    @@strands[Fiber.current]
  end

  # EM/fiber safe sleep.
  def self.sleep(seconds)
    fiber = Fiber.current
    EM::Timer.new(seconds){ fiber.resume }
    Fiber.yield
  end

  # Alias for Fiber.yield.
  def self.yield(*args)
    Fiber.yield(*args)
  end

  # Yield the strand, but have EM resume it on the next tick.
  def self.pass
    fiber = Fiber.current
    EM.next_tick{ fiber.resume }
    Fiber.yield
  end

  # Create and run a strand.
  def initialize(&block)

    # Initialize our "fiber local" storage.
    @locals = {}

    # Condition variable for joining.
    @join_cond = ConditionVariable.new

    # Create our fiber.
    @fiber = Fiber.new{ fiber_body(&block) }

    # Add us to the list of living strands.
    @@strands[@fiber] = self

    # Finally start the strand.
    resume
  end

  # Like Thread#join.
  #   s1 = Strand.new{ Strand.sleep(1) }
  #   s2 = Strand.new{ Strand.sleep(1) }
  #   s1.join
  #   s2.join
  def join
    @join_cond.wait if alive?
    raise @exception if @exception
    true
  end

  # Like Fiber#resume.
  def resume(*args)
    @fiber.resume(*args)
  end

  # Like Thread#alive? or Fiber#alive?
  def alive?
    @fiber.alive?
  end

  # Like Thread#value.  Implicitly calls #join.
  #   strand = Strand.new{ 1+2 }
  #   strand.value # => 3
  def value
    join and @value
  end

  # Access to "strand local" variables, akin to "thread local" variables.
  #   Strand.new do
  #     ...
  #     Strand.current[:connection].send(data)
  #     ...
  #   end
  def [](name)
    @locals[name.to_sym]
  end

  # Access to "strand local" variables, akin to "thread local" variables.
  #   Strand.new do
  #     ...
  #     Strand.current[:connection] = SomeConnectionClass.new(host, port)
  #     ...
  #   end
  def []=(name, value)
    @locals[name.to_sym] = value
  end

  # Is there a "strand local" variable defined called +name+
  def key?(name)
    @locals.has_key?(name.to_sym)
  end

  # The set of "strand local" variable keys
  def keys()
    @locals.keys
  end

  def inspect #:nodoc:
    "#<Strand:0x%s %s" % [object_id, @fiber == Fiber.current ? "run" : "yielded"]
  end

protected
  
  def fiber_body(&block) #:nodoc:
    # Run the strand's block and capture the return value.
    begin
      @value = block.call
    rescue StandardError => e
      @exception = e
    end

    # Mark the strand as finished running.
    @finished = true

    # Delete from the list of running stands.
    @@strands.delete(@fiber)

    # Resume anyone who called join on us.
    @join_cond.signal

    @value || @exception
  end

end
