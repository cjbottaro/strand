class Strand
  # Provides for Strands (Fibers) what Ruby's ConditionVariable provides for Threads.
  class ConditionVariable

    # Create a new condition variable.
    def initialize
      @waiters = []
    end

    # Wait until signaled.  Returns true upon returning.
    #   x = nil
    #   cond = Strand::ConditionVariable.new
    #   Strand.new{ cond.wait; x = 1; cond.signal }
    #   puts x # => nil
    #   cond.signal
    #   cond.wait # => true
    #   puts x # => 1
    # If timeout is a number, then returns false if timed out or true if signaled.
    #   x = nil
    #   cond = Strand::ConditionVariable.new
    #   Strand.new{ cond.wait; x = 1; cond.signal }
    #   puts x # => nil
    #   cond.wait(0.01) # => false
    #   puts x # => nil
    def wait(timeout = nil)
      # Get the fiber that called us.
      fiber = Fiber.current

      # Add the fiber to the list of waiters.
      @waiters << fiber

      # Setup the timer if they specified a timeout
      timer = EM::Timer.new(timeout){ fiber.resume(:timeout) } if timeout

      # Wait for signal or timeout.
      if Fiber.yield == :timeout
        # Timeout occurred.

        # Remove from list of waiters.
        @waiters.delete(fiber)

        false
      else
        # Ok we were signaled.

        # Cancel the timer if there is one.
        timer.cancel if timer

        true
      end

    end

    # Asynchronously resume a fiber waiting on this condition variable.
    # The waiter is not resumed immediately, but on the next tick of EM's reactor loop.
    #   cond = Strand::ConditionVariable.new
    #   Strand.new{ puts 1; cond.wait; puts 2 }
    #   puts 3
    #   cond.signal
    #   puts 4
    #   # output is...
    #   1
    #   3
    #   4
    #   2
    def signal
      # If there are no waiters, do nothing.
      return if @waiters.empty?

      # Find a waiter to wake up.
      waiter = @waiters.shift

      # Resume it on next tick.
      EM.next_tick{ waiter.resume }
    end

  end
end
