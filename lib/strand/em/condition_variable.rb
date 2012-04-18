module Strand
    module EM
        # Provides for Strands (Fibers) what Ruby's ConditionVariable provides for Threads.
        class ConditionVariable

            # Create a new condition variable.
            def initialize
                @waiters = []
            end

            # Using a mutex for condition variables is meant to protect
            # against race conditions when the signal occurs between testing whether
            # a wait is needed and waiting. This situation will never occur with
            # fibers, but the semantic is retained 
            def wait(mutex=nil,timeout = nil)

                if timeout.nil? && (mutex.nil? || Numeric === mutex)
                    timeout = mutex
                    mutex = nil
                end

                # Get the fiber that called us.
                strand = Thread.current
                # Add the fiber to the list of waiters.
                @waiters << strand
                begin
                    sleeper = mutex ? mutex : Thread
                    sleeper.sleep(timeout)
                ensure
                    # Remove from list of waiters.
                    @waiters.delete(strand)
                end
                self
            end

            def signal
                # If there are no waiters, do nothing.
                return self if @waiters.empty?

                # Find a waiter to wake up.
                waiter = @waiters.shift

                # Resume it on next tick.
                ::EM.next_tick{ waiter.wakeup }
                self
            end

            def broadcast
                all_waiting = @waiters.dup
                @waiters.clear
                ::EM.next_tick { all_waiting.each { |w| w.wakeup } }
                self
            end

        end
    end
end
