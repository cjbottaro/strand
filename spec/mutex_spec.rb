require 'spec_helper'

# This spec derived from rubyspec for mutex
describe Strand::Mutex do
    include EM::SpecHelper

    around(:each) do |example|
        em do 
            example.run
            done
        end
    end

    context :lock  do

        it "returns self" do
            m = described_class.new
            m.lock.should == m
            m.unlock
        end

        it "waits if the lock is not available" do
            m = described_class.new

            status = nil
            m.lock

            s = Strand.new do
                m.lock
                status = :after_lock
            end

            status.should be_nil
            m.unlock
            s.join
            status.should == :after_lock
        end

        #GG there's no test for this in rubyspec
        # but there is a test below for locked?
        it "acquires a lock previously held by a dead Fiber" do
            m = Strand::Mutex.new

            m.lock

            # s1 acquires the lock but does not release it before
            # it dies, something needs to resume s2
            # we 
            s1 = Strand.new { m.lock; Strand.pass }
            s2 = Strand.new { m.lock; }

            m.unlock
            s2.join
        end

        it "acquires a lock previously held by a killed Fiber" do
            m = Strand::Mutex.new
            m.lock

            s1 = Strand.new { m.lock; Strand.sleep }
            s2 = Strand.new { m.lock; }

            m.unlock
            s1.kill
            s2.join
        end

        it "acquires a lock in a queue behind a killed Fiber" do

            m = Strand::Mutex.new
            m.lock
            s1 = Strand.new { m.lock }
            s2 = Strand.new { m.lock }
            s3 = Strand.new { m.lock }

            s2.kill
            m.unlock
            s3.join

        end
    end

    context :unlock do
        it "raises FiberError unless Mutex is locked" do
            mutex = described_class.new
            lambda { mutex.unlock }.should raise_error(FiberError)
        end

        it "raises FiberError unless thread owns Mutex" do
            mutex = Strand::Mutex.new
            wait = Strand::Mutex.new
            wait.lock

            s = Strand.new do
                mutex.lock
                wait.lock
            end

            lambda { mutex.unlock }.should raise_error(FiberError)

            wait.unlock
            s.join
        end

        it "raises FiberError if previously locking thread is gone" do
            mutex = Strand::Mutex.new
            s = Strand.new do
                mutex.lock
            end

            s.join
            #TODO This doesn't make sense, because it would raise error
            # as per above test
            lambda { mutex.unlock }.should raise_error(FiberError)
        end
    end

    context :locked do
        it "returns true if locked" do
            m = Strand::Mutex.new
            m.lock
            m.locked?.should be_true
        end

        it "returns false if unlocked" do
            m = Strand::Mutex.new
            m.locked?.should be_false
        end

        it "returns the status of the lock" do

            m1 = Strand::Mutex.new
            m2 = Strand::Mutex.new

            m2.lock # hold s with only m1 locked

            s = Strand.new do
                m1.lock
                m2.lock
            end

            m1.locked?.should be_true
            m2.unlock # release s
            s.join
            #TODO GG implies that I should be able to get m1
            # but there is no test for this case!
            m1.locked?.should be_false
        end
    end

    context :try_lock do
        it "locks the mutex if it can" do
            m = Strand::Mutex.new
            m.try_lock

            m.locked?.should be_true
            lambda { m.try_lock.should be_false }.should_not raise_error(FiberError)
        end

        it "returns false if lock can not be aquired immediately" do
            m1 = Strand::Mutex.new
            m2 = Strand::Mutex.new

            m2.lock
            s = Strand.new do
                m1.lock
                m2.lock
            end

            # s owns m1 so try_lock should return false
            m1.try_lock.should be_false
            m2.unlock
            s.join
            # once th is finished m1 should be released
            m1.try_lock.should be_true
        end
    end
    context :synchronize do
        it "wraps the lock/unlock pair in an ensure" do
            m1 = Strand::Mutex.new
            m2 = Strand::Mutex.new
            m2.lock

            s = Strand.new do
                lambda do
                    m1.synchronize do
                        m2.lock
                        raise Exception
                    end
                end.should raise_error(Exception)
            end

            m1.locked?.should be_true
            m2.unlock
            s.join
            m1.locked?.should be_false
        end
    end

    context :sleep do
        it "raises FiberError if not locked by the current thread" do
            m = Strand::Mutex.new
            lambda { m.sleep }.should raise_error(FiberError)
        end

        it "pauses execution for approximately the duration requested" do
            m = Strand::Mutex.new
            m.lock
            duration = 0.1
            start = Time.now
            m.sleep duration
            (Time.now - start).should be_within(0.1).of(duration)
        end

        it "unlocks the mutex while sleeping" do
            m = Strand::Mutex.new
            s = Strand.new { m.lock; m.sleep }
            m.locked?.should be_false
            # Fails due to no Strand#run
            s.run
            s.join
        end

        it "relocks the mutex when woken" do
            m = Strand::Mutex.new
            m.lock
            m.sleep(0.01)
            m.locked?.should be_true
        end

        it "relocks the mutex when woken by an exception being raised" do
            m = Strand::Mutex.new
            s = Strand.new do
                m.lock
                begin
                    m.sleep
                rescue Exception
                    m.locked?
                end
            end
            s.raise(Exception)
            s.value.should be_true
        end

        it "returns the rounded number of seconds asleep" do
            m = Strand::Mutex.new
            m.lock
            m.sleep(0.01).should be_kind_of(Integer)
        end
    end
end
