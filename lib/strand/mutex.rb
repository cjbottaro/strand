
class Strand
    class Mutex

        @fibers = {}

        def initialize()
            @waiters = []
        end

        def lock()
            fiber = Fiber.current
            @waiters << fiber

            Fiber.yield unless @waiters.first == fiber
            self.class.acquired(fiber,self) 
            self
        end

        def unlock()
            fiber = Fiber.current

            raise FiberError, "not current" unless @waiters.first == fiber

            self.class.released(fiber,self)
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
            Strand.sleep(timeout)
            lock
            timeout.round()
        end

        def self.acquired(fiber,mutex)
            start_lock_reaper(fiber)
            @fibers[fiber]  << mutex
        end

        def self.released(fiber,mutex)
            @fibers[fiber].delete(mutex)
            if @fibers[fiber].size == 1
                @fibers[fiber][0].cancel
                @fibers.delete(fiber)
            end
            unlock(fiber,mutex)
        end

        def self.unlock(fiber,mutex)
            waiters = mutex.instance_variable_get(:@waiters)
            waiters.shift
            EM.next_tick { waiters.first.resume } unless waiters.empty?
        end

        def self.start_lock_reaper(fiber)
            #TODO Generalise this on Strand itself
            # ie register block to call on fiber_body death
            # if Fiber doesn't belong to a Strand then use
            # this periodic timer technique
            unless @fibers[fiber]
                timer = EM.add_periodic_timer(0.5) { reap(fiber) }
                @fibers[fiber] = [ timer ]
            end
        end

        def self.reap(fiber)
            unless fiber.alive?
                locks = @fibers.delete(fiber)
                locks.shift.cancel
                locks.each { |m| unlock(fiber,m) }
            end
        end
    end
end
