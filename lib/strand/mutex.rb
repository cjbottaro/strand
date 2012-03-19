
class Strand
    class Mutex

        @fibers = {}

        def initialize()
            @waiters = []
        end

        def lock()
            strand = Strand.current
            @waiters << strand
            strand.send(:yield_sleep) unless @waiters.first == strand
            # Now strand has the lock, make sure it is released if the strand dies
            strand.ensure_hook(self) { release() unless waiters.empty? || waiters.first != strand } 
            self
        end

        def unlock()
            strand = Strand.current
            raise FiberError, "not owner" unless @waiters.first == strand
            release()
        end

        def locked?
            !@waiters.empty? && @waiters.first.alive?
        end

        def try_lock
            lock unless locked?
        end

        def synchronize(&block)
            lock
            yield
            ensure
                unlock
        end

        def sleep(timeout=nil)
            unlock
            begin
                 Strand.sleep(timeout)
                 if timeout.nil? then 0 else timeout.round() end
            ensure
                lock
            end
        end
    
        private
            attr_reader :waiters

        def release()
            # release the current lock holder, and clear the strand death hook
            waiters.shift.ensure_hook(self) 

            EM.next_tick do
                waiters.shift until waiters.empty? || waiters.first.alive?
                waiters.first.send(:wake_resume) unless waiters.empty?
            end
        end
    end
end
