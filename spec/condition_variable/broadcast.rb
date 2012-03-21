
shared_examples_for "ConditionVariable#broadcast" do

    context "#broadcast" do
        it "returns self if nothing to broadcast to" do
            cv = Strand::ConditionVariable.new
            cv.broadcast.should == cv
        end

        it "returns self if something is waiting for a broadcast" do
            m = Strand::Mutex.new
            cv = Strand::ConditionVariable.new
            th = Strand.new do
                m.synchronize do
                    cv.wait(m)
                end
            end

            m.synchronize { cv.broadcast }.should == cv

            th.join
        end

        it "releases all strands waiting in line for this resource" do
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
            Strand.pass until strands.all? {|th| th.status == "sleep" }
            r2.should be_empty
            m.synchronize do
                cv.broadcast
            end

            strands.each {|t| t.join }

            # ensure that all strands that enter cv.wait are released
            r2.sort.should == r1.sort
            # note that order is not specified as broadcast results in a race
            # condition on regaining the lock m
        end
    end
end
