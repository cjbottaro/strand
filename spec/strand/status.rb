shared_examples_for "Strand#status" do
    context :status do
        it "can check it's own status" do
            StrandSpecs.status_of_current_strand.status.should == 'run'
        end

        quarantine! do
            # There's no way to interact with a running strand from another strand
            it "describes a running strand" do
                StrandSpecs.status_of_running_strand.status.should == 'run'
            end
        end

        it "describes a sleeping strand" do
            StrandSpecs.status_of_sleeping_strand.status.should == 'sleep'
        end

        it "describes a blocked strand" do
            StrandSpecs.status_of_blocked_strand.status.should == 'sleep'
        end

        it "describes a completed strand" do
            StrandSpecs.status_of_completed_strand.status.should == false
        end

        it "describes a killed strand" do
            StrandSpecs.status_of_killed_strand.status.should == false
        end

        it "describes a strand with an uncaught exception" do
            StrandSpecs.status_of_strand_with_uncaught_exception.status.should == nil
        end

        it "describes a dying sleeping strand" do
            StrandSpecs.status_of_dying_sleeping_strand.status.should == 'sleep'
        end

        quarantine! do
            it "reports aborting on a killed strand" do
                StrandSpecs.status_of_aborting_strand.status.should == 'aborting'
            end
        end
    end
end
