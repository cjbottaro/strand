require "spec_helper"

describe Strand::ConditionVariable do
  include EM::SpecHelper

  context "calling #wait" do
    before(:each) do
      @cond = described_class.new
      @atc = Atc.new :timeout => 0.01
    end
    it "should block until signaled" do
      em do
        Strand.new{ @cond.wait; @atc.signal(1) }
        @atc.wait(1).should be_false
        @cond.signal
        @atc.wait(1).should be_true
        done
      end
    end
    it "should block until timed out" do
      em do
        Strand.new{ @cond.wait(0.02); @atc.signal(1) }
        @atc.wait(1).should be_false
        @atc.wait(1).should be_true
        done
      end
    end
  end

  context "calling #signal" do
    context "with no waiters" do
      before(:all){ @cond = described_class.new }
      it "should not do anything" do
        @cond.signal.should be_nil
      end
    end
    context "with a single waiter" do
      before(:all) do
        @cond = described_class.new
        @atc = Atc.new :timeout => 0.01
        Strand.new{ @cond.wait; @atc.signal(1) }
      end
      it "should wake up the waiter" do
        em do
          @atc.wait(1).should be_false
          @cond.signal
          @atc.wait(1).should be_true
          done
        end
      end
    end
    context "with multiple waiters" do
      before(:all) do
        @cond = described_class.new
        @atc = Atc.new :timeout => 0.01
        Strand.new{ @cond.wait; @atc.signal(1) }
        Strand.new{ @cond.wait; @atc.signal(2) }
      end
      it "should wake up the first waiter" do
        em do
          @atc.wait(1).should be_false
          @atc.wait(2).should be_false
          @cond.signal
          @atc.wait(1).should be_true
          @atc.wait(2).should be_false
          done
        end
      end
      it "then wake up the second waiter" do
        em do
          @atc.wait(1).should be_true
          @atc.wait(2).should be_false
          @cond.signal
          @atc.wait(1).should be_true
          @atc.wait(2).should be_true
          done
        end
      end
    end
  end

end
