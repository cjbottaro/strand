module Strand
    module EM
        # A Strand equivalent to ::Queue from thread.rb
        #     queue = Strand::Queue.new
        # 
        #     producer = Strand.new do
        #          5.times do |i|
        #              Strand.sleep rand(i) # simulate expense
        #              queue << i
        #              puts "#{i} produced"
        #          end            
        #      end
        #
        #      consumer = Strand.new do
        #          5.times do |i|
        #              value = queue.pop
        #              Strand.sleep rand(i/2) # simulate expense
        #              puts "consumed #{value}"
        #          end            
        #      end
        #
        #      consumer.join
        #
        class Queue

            # Creates a new queue
            def initialize
                @mutex = Mutex.new()            
                @cv = ConditionVariable.new()
                @q = []
                @waiting = 0
            end

            # Pushes +obj+ to the queue
            def push(obj)
                @q << obj
                @mutex.synchronize { @cv.signal }
            end
            alias :<< :push
            alias :enq :push

            # Retrieves data from the queue.
            #
            #
            # If the queue is empty, the calling fiber is suspended until data is
            # pushed onto the queue, unless +non_block+ is true in which case a
            # +FiberError+ is raised
            #
            def pop(non_block=false)
                raise FiberError, "queue empty" if non_block && empty?
                if empty?
                    @waiting += 1
                    @mutex.synchronize { @cv.wait(@mutex) if empty? }
                    @waiting -= 1
                end
                # array.pop is like a stack, we're a FIFO
                @q.shift
            end
            alias :shift :pop
            alias :deq :pop

            # Returns the length of the queue
            def length
                @q.length
            end
            alias :size :length

            # Returns +true+ if the queue is empty
            def empty?
                @q.empty?
            end

            # Removes all objects from the queue
            def clear
                @q.clear
            end

            # Returns the number of fibers waiting on the queue
            def num_waiting
                @waiting
            end
        end
    end
end
