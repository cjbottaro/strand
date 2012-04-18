# This file is derived from MRI Ruby 1.9.3 monitor.rb
#
# Copyright (C) 2001  Shugo Maeda <shugo@ruby-lang.org>
#
# This library is distributed under the terms of the Ruby license.
# You can freely distribute/modify this library.
#


module Strand

    # See MRI Ruby's MonitorMixin
    module MonitorMixin
        
        class ConditionVariable
            
            #
            # Releases the lock held in the associated monitor and waits; reacquires the lock on wakeup.
            #
            # If +timeout+ is given, this method returns after +timeout+ seconds passed,
            # even if no other thread doesn't signal.
            #
            def wait(timeout = nil)
                @monitor.__send__(:mon_check_owner)
                count = @monitor.__send__(:mon_exit_for_cond)
                begin
                    @cond.wait(@monitor.instance_variable_get("@mon_mutex"), timeout)
                    return true
                ensure
                    @monitor.__send__(:mon_enter_for_cond, count)
                end
            end

            #
            # Calls wait repeatedly while the given block yields a truthy value.
            #
            def wait_while
                while yield
                    wait
                end
            end

            #
            # Calls wait repeatedly until the given block yields a truthy value.
            #
            def wait_until
                until yield
                    wait
                end
            end

            #
            # Wakes up the first thread in line waiting for this lock.
            #
            def signal
                @monitor.__send__(:mon_check_owner)
                @cond.signal
            end

            #
            # Wakes up all threads waiting for this lock.
            #
            def broadcast
                @monitor.__send__(:mon_check_owner)
                @cond.broadcast
            end

            private

            def initialize(monitor)
                @monitor = monitor
                @cond = ConditionVariable.new
            end
        end

        def self.extend_object(obj)
            super(obj)
            obj.__send__(:mon_initialize)
        end

        #
        # Attempts to enter exclusive section.  Returns +false+ if lock fails.
        #
        def mon_try_enter
            if @mon_owner != Strand.current
                unless @mon_mutex.try_lock
                    return false
                end
                @mon_owner = Strand.current
            end
            @mon_count += 1
            return true
        end
        # For backward compatibility
        alias try_mon_enter mon_try_enter

        #
        # Enters exclusive section.
        #
        def mon_enter
            if @mon_owner != Strand.current
                @mon_mutex.lock
                @mon_owner = Strand.current
            end
            @mon_count += 1
        end

        #
        # Leaves exclusive section.
        #
        def mon_exit
            mon_check_owner
            @mon_count -=1
            if @mon_count == 0
                @mon_owner = nil
                @mon_mutex.unlock
            end
        end

        #
        # Enters exclusive section and executes the block.  Leaves the exclusive
        # section automatically when the block exits.  See example under
        # +MonitorMixin+.
        #
        def mon_synchronize
            mon_enter
            begin
                yield
            ensure
                mon_exit
            end
        end
        alias synchronize mon_synchronize

        #
        # Creates a new MonitorMixin::ConditionVariable associated with the
        # receiver.
        #
        def new_cond
            return ConditionVariable.new(self)
        end

        private

        # Use <tt>extend MonitorMixin</tt> or <tt>include MonitorMixin</tt> instead
        # of this constructor.  Have look at the examples above to understand how to
        # use this module.
        def initialize(*args)
            super
            mon_initialize
        end

        # Initializes the MonitorMixin after being included in a class or when an
        # object has been extended with the MonitorMixin
        def mon_initialize
            @mon_owner = nil
            @mon_count = 0
            @mon_mutex = Mutex.new
        end

        def mon_check_owner
            if @mon_owner != Strand.current
                raise Strand.delegate_class(ThreadError,FiberError), "current thread not owner"
            end
        end

        def mon_enter_for_cond(count)
            @mon_owner = Strand.current
            @mon_count = count
        end

        def mon_exit_for_cond
            count = @mon_count
            @mon_owner = nil
            @mon_count = 0
            return count
        end
    end

    # Use the Monitor class when you want to have a lock object for blocks with
    # mutual exclusion.
    #
    #   require 'monitor'
    #
    #   lock = Monitor.new
    #   lock.synchronize do
    #     # exclusive access
    #   end
    #
    class Monitor
        include MonitorMixin
        alias try_enter try_mon_enter
        alias enter mon_enter
        alias exit mon_exit
    end

end
