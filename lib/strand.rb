if defined?(EventMachine)
    require 'strand/em/thread.rb'
    require 'strand/em/queue.rb'
end

module Strand
    
    THREAD, MUTEX, COND_VAR, QUEUE  = 
        if defined?(EventMachine)
            [ Strand::EM::Thread,
              Strand::EM::Mutex,
              Strand::EM::ConditionVariable,
              Strand::EM::Queue ]
        end

    def self.event_machine?
        THREAD && EventMachine.reactor_running? && EventMachine.reactor_thread?
    end

    def self.delegate_class(thread_class,fiber_class)
        if self.event_machine? then
            fiber_class
        else
            thread_class
        end
    end
    
    def self.list
        delegate_class(::Thread,THREAD).list()
    end

    def self.current
        delegate_class(::Thread,THREAD).current()
    end

    def self.sleep(*a)
        delegate_class(Kernel,THREAD).sleep(*a)
    end

    def self.stop()
        delegate_class(::Thread,THREAD).stop() 
    end

    def self.pass()
        delegate_class(::Thread,THREAD).pass()
    end


    def self.new(*args,&block)
        delegate_class(::Thread,THREAD).new(*args,&block)
    end

    module Mutex
        def self.new(*args,&block)
            Strand.delegate_class(::Mutex,MUTEX).new(*args,&block)
        end
    end
    module ConditionVariable
        def self.new(*args,&block)
            Strand.delegate_class(::ConditionVariable,COND_VAR).new(*args,&block)
        end
    end
    module Queue
        def self.new(*args,&block)
            Strand.delegate_class(::Queue,QUEUE).new(*args,&block)
        end
    end
end
