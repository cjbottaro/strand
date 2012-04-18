shared_examples_for "Strand#wakeup" do

    context :wakeup do
        it "can interrupt Strand#sleep" do
            exit_loop = false
            after_sleep1 = false
            after_sleep2 = false

            t = Strand.new do
                while true
                    #Unlike a thread, we need to pass
                    Strand.pass
                    break if exit_loop == true
                end

                Strand.sleep
                after_sleep1 = true

                Strand.sleep
                after_sleep2 = true
            end

            exit_loop = true

            after_sleep1.should == false # t should be blocked on the first sleep
            t.send(:wakeup)

            after_sleep2.should == false # t should be blocked on the second sleep
            t.send(:wakeup)

            t.join
        end

        it "does not result in a deadlock" do
            t = Strand.new do
                10.times { Strand.stop }
            end

            while(t.status != false) do
                begin
                    t.send(:wakeup)
                rescue StrandError
                    # The strand might die right after.
                    t.status.should == false
                end
            end

            1.should == 1 # test succeeds if we reach here
        end

        it "raises a StrandError when trying to wake up a dead strand" do
            t = Strand.new { 1 }
            t.join
            lambda { t.wakeup }.should raise_error(FiberError)
        end
    end
end
