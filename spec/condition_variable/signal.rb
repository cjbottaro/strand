shared_examples_for "ConditionVariable#signal" do
    context :signal do
        it "returns self if nothing to signal" do
            cv = Strand::ConditionVariable.new
            cv.signal.should == cv
        end

        it "returns self if something is waiting for a signal" do
            m = Strand::Mutex.new
            cv = Strand::ConditionVariable.new
            th = Strand.new do
                m.synchronize do
                    cv.wait(m)
                end
            end

            # ensures that th grabs m before current strand
            Strand.pass while th.status and th.status != "sleep"

            m.synchronize { cv.signal }.should == cv

            th.join
        end

        it "releases the first strand waiting in line for this resource" do
            m = Strand::Mutex.new
            cv = Strand::ConditionVariable.new
            strands = []
            r1 = []
            r2 = []

            # large number to attempt to cause race conditions
            10.times do |i|
                strands << Strand.new(i) do |tid|
                    m.synchronize do
                        r1 << tid
                        cv.wait(m)
                        r2 << tid
                    end
                end
            end

            # wait for all strands to acquire the mutex the first time
            Strand.pass until m.synchronize { r1.size == strands.size }
            # wait until all strands are sleeping (ie waiting)
            Strand.pass until strands.all? {|th| th.status == "sleep" || !thread.status } 
            r2.should be_empty
            10.times do |i|
                m.synchronize do
                    cv.signal
                end
                Strand.pass until r2.size == i+1
            end

            strands.each {|t| t.join }

            # ensure that all the strands that went into the cv.wait are
            # released in the same order
            r2.should == r1
        end
    end
end
