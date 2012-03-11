require 'spec_helper'

# These specs are derived from rubyspec for ruby's standard Queue class
describe Strand::Queue do
    include EM::SpecHelper

    around(:each) do |example|
        em do
            example.run
            done
        end
    end

    context :enqueue do

        it "adds an element to the Queue" do
            q = described_class.new
            q.size.should == 0
            q << Object.new
            q.size.should == 1
            q.push(Object.new)
            q.size.should == 2
            q.enq(Object.new)
            q.size.should == 3
        end

    end

    context :dequeue do
        it "removes an item from the Queue" do
            q = described_class.new
            q << Object.new
            q.size.should == 1
            q.pop
            q.size.should == 0
        end

        it "returns items in the order they were added" do
            q = described_class.new
            q << 1
            q << 2
            q.deq.should == 1
            q.shift.should == 2
        end

        it "blocks the Fiber until there are items in the queue" do
            q = described_class.new
            v = 0

            f = Fiber.new do
                q.pop
                v = 1
            end
            f.resume

            v.should == 0
            q << Object.new
            Strand.pass while f.alive?
            v.should == 1
        end

        it "raises a FiberError if Queue is empty" do
            q = described_class.new
            lambda { q.pop(true) }.should raise_error(FiberError)
        end
    end

    context :length do
        it "returns the number of elements" do
            q = described_class.new
            q.length.should == 0
            q << Object.new
            q << Object.new
            q.length.should == 2
        end
    end

    context :empty do
        it "returns true on an empty Queue" do
            q = described_class.new
            q.empty?.should be_true
        end

        it "returns false when Queue is not empty" do
            q = described_class.new
            q << Object.new
            q.empty?.should be_false
        end
    end

    context :num_waiting do
        it "reports the number of Fibers waiting on the Queue" do
            q = described_class.new
            fibers = []

            5.times do |i|
                q.num_waiting.should == i
                f = Fiber.new { q.deq }
                f.resume
                fibers << f
            end

            fibers.each { q.enq Object.new }

            fibers.each { |f| Strand.pass while f.alive? }

            q.num_waiting.should == 0
        end
    end

    context :doc_example do
        it "handles the doc example" do
            queue = Strand::Queue.new

            producer = Strand.new do
                5.times do |i|
                    Strand.sleep rand(i/4) # simulate expense
                    queue << i
                    puts "#{i} produced"
                end            
            end

            consumer = Strand.new do
                5.times do |i|
                    value = queue.pop
                    Strand.sleep rand(i/8) # simulate expense
                    puts "consumed #{value}"
                end            
            end

            consumer.join
        end
    end
end
