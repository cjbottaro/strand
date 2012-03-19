
shared_examples_for "Strand#exit"  do

    context :exit do
        it "kills sleeping strand" do
            sleeping_strand = Strand.new do
                Strand.sleep
                ScratchPad.record :after_sleep
            end
            sleeping_strand.exit
            sleeping_strand.join
            ScratchPad.recorded.should == nil
        end

        it "kills current strand" do
            strand = Strand.new do
                Strand.current.kill
                ScratchPad.record :after_sleep
            end
            strand.join
            ScratchPad.recorded.should == nil
        end

        it "runs ensure clause" do
            strand = StrandSpecs.dying_strand_ensures(:kill) { ScratchPad.record :in_ensure_clause }
            strand.join
            ScratchPad.recorded.should == :in_ensure_clause
        end

        it "runs nested ensure clauses" do
            ScratchPad.record []
            outer = Strand.new do
                begin
                    inner = Strand.new do
                        begin
                            Strand.sleep
                        ensure
                            ScratchPad << :inner_ensure_clause
                        end
                    end
                    Strand.sleep
                ensure
                    ScratchPad << :outer_ensure_clause
                    inner.exit
                    inner.join
                end
            end
            outer.terminate
            outer.join
            ScratchPad.recorded.should include(:inner_ensure_clause)
            ScratchPad.recorded.should include(:outer_ensure_clause)
        end

        it "does not set $!" do
            strand = StrandSpecs.dying_strand_ensures(:kill) { ScratchPad.record $! }
            strand.join
            ScratchPad.recorded.should == nil
        end

        it "cannot be rescued" do
            strand = Strand.new do
                begin
                    Strand.current.kill
                rescue Exception
                    ScratchPad.record :in_rescue
                end
                ScratchPad.record :end_of_strand_block
            end

            strand.join
            ScratchPad.recorded.should == nil
        end

        it "killing dying running does nothing" do
            # Not applicable for Strands (there can be no "running" status)
        end

        quarantine! do

            it "propogates inner exception to Strand.join if there is an outer ensure clause" do
                strand = StrandSpecs.dying_strand_with_outer_ensure(:kill) { }
                lambda { strand.join }.should raise_error(RuntimeError, "In dying strand")
            end

            it "runs all outer ensure clauses even if inner ensure clause raises exception" do
                strand = StrandSpecs.join_dying_strand_with_outer_ensure(:kill) { ScratchPad.record :in_outer_ensure_clause }
                ScratchPad.recorded.should == :in_outer_ensure_clause
            end

            it "sets $! in outer ensure clause if inner ensure clause raises exception" do
                strand = StrandSpecs.join_dying_strand_with_outer_ensure(:kill) { ScratchPad.record $! }
                ScratchPad.recorded.to_s.should == "In dying strand"
            end
        end

        it "can be rescued by outer rescue clause when inner ensure clause raises exception" do
            strand = Strand.new do
                begin
                    begin
                        Strand.current.send(:kill)
                    ensure
                        raise "In dying strand"
                    end
                rescue Exception
                    ScratchPad.record $!
                end
                :end_of_strand_block
            end

            strand.value.should == :end_of_strand_block
            ScratchPad.recorded.to_s.should == "In dying strand"
        end

        it "is deferred if ensure clause does Strand.stop" do
            StrandSpecs.wakeup_dying_sleeping_strand(:kill) { Strand.stop; ScratchPad.record :after_sleep }
            ScratchPad.recorded.should == :after_sleep
        end

        # Hangs on 1.8.6.114 OS X, possibly also on Linux
        # FIX: There is no such thing as not_compliant_on(:ruby)!!!
        quarantine! do
            not_compliant_on(:ruby) do # Doing a sleep in the ensure block hangs the process
                it "is deferred if ensure clause sleeps" do
                    StrandSpecs.wakeup_dying_sleeping_strand(:kill) { sleep; ScratchPad.record :after_sleep }
                    ScratchPad.recorded.should == :after_sleep
                end
            end

            # This case occurred in JRuby where native strands are used to provide
            # the same behavior as MRI green strands. Key to this issue was the fact
            # that the strand which called #exit in its block was also being explicitly
            # sent #join from outside the strand. The 100.times provides a certain
            # probability that the deadlock will occur. It was sufficient to reliably
            # reproduce the deadlock in JRuby.
            it "does not deadlock when called from within the strand while being joined from without" do
                100.times do
                    t = Strand.new { Strand.stop; Strand.current.send(:kill) }
                    t.wakeup.should == t
                    t.join.should == t
                end
            end
        end
    end
end
