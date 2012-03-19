
shared_examples_for "Strand#stop" do

    context :stop  do
        it "causes the current strand to sleep indefinitely" do
            t = Strand.new { Strand.stop; 5 }
            t.status.should == 'sleep'
            t.run
            t.value.should == 5
        end
    end

    context "stop?" do
        it "can check it's own status" do
            StrandSpecs.status_of_current_strand.stop?.should == false
        end
        quarantine! do
          #Can't really have a running strand
        it "describes a running strand" do
            StrandSpecs.status_of_running_strand.stop?.should == false
        end
        end
        it "describes a sleeping strand" do
            StrandSpecs.status_of_sleeping_strand.stop?.should == true
        end

        it "describes a blocked strand" do
            StrandSpecs.status_of_blocked_strand.stop?.should == true
        end

        it "describes a completed strand" do
            StrandSpecs.status_of_completed_strand.stop?.should == true
        end

        it "describes a killed strand" do
            StrandSpecs.status_of_killed_strand.stop?.should == true
        end

        it "describes a strand with an uncaught exception" do
            StrandSpecs.status_of_strand_with_uncaught_exception.stop?.should == true
        end

        it "describes a dying running strand" do
            StrandSpecs.status_of_dying_running_strand.stop?.should == false
        end

        it "describes a dying sleeping strand" do
            StrandSpecs.status_of_dying_sleeping_strand.stop?.should == true
        end

        quarantine! do
            it "reports aborting on a killed strand" do
                StrandSpecs.status_of_aborting_strand.stop?.should == false
            end
        end
    end
end
