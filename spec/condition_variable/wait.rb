shared_examples_for "ConditionVariable#wait" do
    context :wait do
        it "returns self" do
            m = Strand::Mutex.new
            cv = Strand::ConditionVariable.new

            th = Strand.new do
                m.synchronize do
                    cv.wait(m).should == cv
                end
            end

            # ensures that th grabs m before current thread
            Strand.pass while th.status and th.status != "sleep"

            m.synchronize { cv.signal }
            th.join
        end
    end
end
