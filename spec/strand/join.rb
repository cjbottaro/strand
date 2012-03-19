shared_examples_for "Strand#join" do

    context :join do
        it "returns the strand when it is finished" do
            t = Strand.new {}
            t.join.should equal(t)
        end

        it "returns the strand when it is finished when given a timeout" do
            t = Strand.new {}
            t.join
            t.join(0).should equal(t)
        end

        it "returns nil if it is not finished when given a timeout" do
            c = Channel.new
            t = Strand.new { c.receive }
            begin
                t.join(0).should == nil
            ensure
                c << true
            end
            t.join.should == t
        end

        it "accepts a floating point timeout length" do
            c = Channel.new
            t = Strand.new { c.receive }
            begin
                t.join(0.01).should == nil
            ensure
                c << true
            end
            t.join.should == t
        end

        it "raises any exceptions encountered in the strand body" do
            t = Strand.new { raise NotImplementedError.new("Just kidding") }
            lambda { t.join }.should raise_error(NotImplementedError)
        end

        it "returns the dead strand" do
            t = Strand.new { Strand.current.kill }
            t.join.should equal(t)
        end

        quarantine! do
        # This was pre 1.9 behaviour
        it "returns the dead strand even if an uncaught exception is thrown from ensure block" do
            t = StrandSpecs.dying_strand_ensures { raise "In dying strand" }
            t.join.should equal(t)
        end
        end

        it "raises any uncaught exception encountered in ensure block" do
            t = StrandSpecs.dying_strand_ensures { raise NotImplementedError.new("Just kidding") }
            lambda { t.join }.should raise_error(NotImplementedError)
        end
    end
end
