require 'thread'
require 'fiber'



# This module provides a shim between using standard ruby Threads
# and the thread-like behaviour for Fibers provided by classes in
# the Strand::EM module
# 
# @example
#   # For the Strand::EM classes to be available
#   # you must first load EventMachine
#   'require eventmachine'
#
#   # If you require 'eventmachine' and also need standard Thread behaviour
#   # you'll also need to require 'thread'
#   'require thread'
#
#   'require strand'
#
#   t = Strand.new() do
#       # "t" is a standard ::Thread
#       ...something...
#   end
#
#   EventMachine.run do
#      t = Strand.new() do
#           # "t" is a ::Strand::EM::Thread
#           # which wraps a ::Fiber
#      end
#   end
#   
module Strand

    # Test whether we have real fibers or a thread based fiber implmentation
    t = Thread.current
    ft = nil
    Fiber.new { ft = Thread.current }.resume
    ROOT_FIBER = Fiber.current
    REAL_FIBERS = ( t == ft )

    def self.reload()
        @em_class_map = if defined?(EventMachine) then enable_eventmachine() else nil end
    end

    def self.enable_eventmachine
        return false unless defined?(EventMachine)

        require 'strand/em/thread.rb'
        require 'strand/em/queue.rb'

        # Classes if eventmachine has been previously loaded
        {
            ::Thread => Strand::EM::Thread,
            ::Kernel => Strand::EM::Thread,
            ::Mutex  => Strand::EM::Mutex,
            ::ConditionVariable => Strand::EM::ConditionVariable,
            ::Queue => Strand::EM::Queue
        }
    end

    reload()

    # If EM already required then enable it, otherwise defer until first use
    def self.event_machine?
        @em_class_map = enable_eventmachine() if @em_class_map.nil?

        # If the ruby VM does not have native fibers (eg JRuby) then EM.reactor_thread?
        # will return false for code executing in a fiber. In this case we assume that
        # if the reactor is running and we're not in the root fiber then we are probably
        # within the event machine loop. #TODO is there a better way?
        @em_class_map && EventMachine.reactor_running? &&
                ( EventMachine.reactor_thread? || (!REAL_FIBERS && ROOT_FIBER != Fiber.current))
    end

    # @return either thread_class or fiber_class depending on whether we are running
    #         in the EventMachine reactor
    def self.delegate_class(class_key)
        if self.event_machine? then @em_class_map[class_key] else class_key end
    end

    # Analogous to Thread#list
    def self.list
        delegate_class(::Thread).list()
    end

    # Analogous to Thread#current
    def self.current
        delegate_class(::Thread).current()
    end

    # Analogous to Kernel#sleep
    def self.sleep(*a)
        delegate_class(::Kernel).sleep(*a)
    end

    # Analagous to Thread#stop
    def self.stop()
        delegate_class(::Thread).stop() 
    end

    # Analagous to Thread#pass
    def self.pass()
        delegate_class(::Thread).pass()
    end

    # Convenience to call Fiber.yield
    # This is independant of eventmachine etc..
    # WARNING: It is a very bad idea to use the raw fiber methods
    # AND the EM::Thread#sleep/wakeup methods on the same fiber
    def self.yield(*args)
        Fiber.yield(*args)
    end

    # Fake Thread like class
    # @return A new instance of either ::Thread or ::Strand::EM::Thread
    def self.new(*args,&block)
        delegate_class(::Thread).new(*args,&block)
    end

    # Fake mutex class, delegates to ::Mutex or Strand::EM::Mutex
    module Mutex
        def self.new(*args,&block)
            Strand.delegate_class(::Mutex).new(*args,&block)
        end
    end

    # Fake ConditionVariable class, delegates to ::ConditionVariable
    # or Strand::EM::ConditionVariable
    module ConditionVariable
        def self.new(*args,&block)
            Strand.delegate_class(::ConditionVariable).new(*args,&block)
        end
    end

    # Fake Queue class, delegates to ::Queue or Strand::EM::ConditionVariable
    module Queue
        def self.new(*args,&block)
            Strand.delegate_class(::Queue).new(*args,&block)
        end
    end
end
