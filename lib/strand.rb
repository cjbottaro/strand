require "fiber"
require "eventmachine"
require "strand/condition_variable"
require "strand/queue"
require "strand/mutex"

#TODO If strand methods are called on Fibers that are not strands
# create a special Strand instance with a cleanup job that detects
# fiber death. 
# those kind of strands would not be able to be killed
class ProxyStrand < Strand
    def initialize(fiber)
        init(fiber)
    end
end

#Acts like a thread using Fibers and EventMachine
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
        @@strands[Fiber.current] || ProxyStrand.new(Fiber.current)
    end

    # Alias for Fiber.yield
    # Equivalent to a thread being blocked on IO
    def self.yield(*args)
        Fiber.yield(*args)
    end

    # EM/fiber safe sleep.
    def self.sleep(seconds=nil)
        strand = Strand.current
        timer = EM::Timer.new(seconds){ strand.send(:wake_resume) } if seconds
        strand.send(:yield_sleep,timer)
    end

    def self.stop
        self.sleep()
    end

    # EM/fiber safe pass
    # The strand is resume on the next_tick of EM's event loop
    def self.pass
        strand = Strand.current
        EM.next_tick{ strand.send(:wake_resume) }
        strand.send(:yield_sleep)
    end

    # Create and run a strand.
    def initialize(*args,&block)

        # Create our fiber.
        fiber = Fiber.new{ fiber_body(&block) }

        init(fiber)

        # Finally start the strand.
        fiber.resume(*args)
    end

    # Like Thread#join.
    #   s1 = Strand.new{ Strand.sleep(1) }
    #   s2 = Strand.new{ Strand.sleep(1) }
    #   s1.join
    #   s2.join
    def join(limit = nil)
        join_result = if alive? && !@join_cond.wait(limit) then nil else self end
        Kernel.raise @exception if @exception
        join_result 
    end

    # Like Fiber#resume.
    def resume(*args)
        #TODO  should only allow if @status is :run, which really means
        # blocked by a call to Yield
        @fiber.resume(*args)
    end

    # Like Thread#alive? or Fiber#alive?
    def alive?
        fiber.alive?
    end

    def stop?
        #by definition anything except the current fiber is stopped
        Fiber.current != fiber
    end

    def status
        case @status
        when :run
            #TODO - only if the current thread, otherwise
            # we can only be in this state due to a yield on the
            # underlying fiber, which means we are actually in sleep
            # or actually a proxy strand could be dead and not yet
            # detected
            "run"
        when :sleep
            "sleep"
        when :dead, :killed
            false
        when :exception
            nil
        end
    end

    # Like Thread#value.  Implicitly calls #join.
    #   strand = Strand.new{ 1+2 }
    #   strand.value # => 3
    def value
        join and @value
    end

    def exit
        case @status
        when :sleep
            wake_resume(:exit)
        when :run
            throw :exit
        end
    end

    alias :kill :exit
    alias :terminate :exit

    def wakeup
        Kernel.raise FiberError, "dead strand" unless status
        wake_resume() 
    end

    def raise(*args)
        if fiber == Fiber.current
            Kernel.raise *args 
        elsif status
            args << RuntimeError if args.empty?
            wake_resume(:raise,*args)
        else
            #dead strand, do nothing
        end
    end

    alias :run :wakeup


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

    def ensure_hook(key,&block)
        if block_given? then 
            @ensure_hooks[key] = block
        else
            @ensure_hooks.delete(key)
        end
    end

    protected

    def fiber_body(&block) #:nodoc:
        # Run the strand's block and capture the return value.
        @status = :run

        @value = nil, @exception = nil
        catch :exit do
            begin
                @value = block.call
                @status = :dead
            rescue Exception => e
                @exception = e
                @status = :exception
            ensure
                run_ensure_hooks()
            end
        end

        # Delete from the list of running stands.
        @@strands.delete(@fiber)

        # Resume anyone who called join on us.
        @join_cond.signal

        @value || @exception
    end

    private

    def init(fiber)
        @fiber = fiber
        # Add us to the list of living strands.
        @@strands[@fiber] = self

        # Initialize our "fiber local" storage.
        @locals = {}

        # Record the status
        @status = nil

        # Hooks to run when the strand dies (eg by Mutex to release locks)
        @ensure_hooks = {}

        # Condition variable for joining.
        @join_cond = ConditionVariable.new

    end
    def yield_sleep(timer=nil)
        @status = :sleep
        event,*args = Fiber.yield
        timer.cancel if timer
        case event
        when :exit
            @status = :killed
            throw :exit
        when :wake
            @status = :run
        when :raise
            Kernel.raise *args
        end
    end

    def wake_resume(event = :wake,*args)
        fiber.resume(event,*args) if @status == :sleep 
        #TODO if fiber is still alive? and status = :run
        # then it has been yielded from non Strand code. 
        # if it is not alive, and is a proxy strand then
        # we can signal the condition variable from here
    end

    def run_ensure_hooks()
        #TODO - better not throw exceptions in an ensure hook
        @ensure_hooks.each { |key,hook| hook.call }
    end
end
