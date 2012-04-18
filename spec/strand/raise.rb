shared_examples_for "Strand#raise" do
    context :raise do
        it "ignores dead strands" do
            t = Strand.new { :dead }
            Strand.pass while t.alive?
            lambda {t.raise("Kill the strand")}.should_not raise_error
            lambda {t.value}.should_not raise_error
        end
    end

    context "Strand#raise on a sleeping strand" do
        before :each do
            ScratchPad.clear
            @str = StrandSpecs.sleeping_strand
            Strand.pass while @str.status and @str.status != "sleep"
        end

        after :each do
            @str.kill
        end

        it "raises a RuntimeError if no exception class is given" do
            @str.raise
            Strand.pass while @str.status
            ScratchPad.recorded.should be_kind_of(RuntimeError)
        end

        it "raises the given exception" do
            @str.raise Exception
            Strand.pass while @str.status
            ScratchPad.recorded.should be_kind_of(Exception)
        end

        it "raises the given exception with the given message" do
            @str.raise Exception, "get to work"
            Strand.pass while @str.status
            ScratchPad.recorded.should be_kind_of(Exception)
            ScratchPad.recorded.message.should == "get to work"
        end

        it "is captured and raised by Strand#value" do
            t = Strand.new do
                Strand.sleep
            end

            StrandSpecs.spin_until_sleeping(t)

            t.raise
            lambda { t.value }.should raise_error(RuntimeError)
        end

        it "raises a RuntimeError when called with no arguments" do
            t = Strand.new do
                begin
                    1/0
                rescue ZeroDivisionError
                    Strand.sleep 3
                end
            end
            begin
                raise RangeError
            rescue
                StrandSpecs.spin_until_sleeping(t)
                t.raise
            end
            lambda {t.value}.should raise_error(RuntimeError)
            t.kill
        end
    end

    #TODO do these make sense?
    quarantine! do

        context "Strand#raise on a running strand" do
            before :each do
                ScratchPad.clear
                StrandSpecs.clear_state

                @str = StrandSpecs.running_strand
                Strand.pass until StrandSpecs.state == :running
            end

            after :each do
                @str.kill
            end

            it "raises a RuntimeError if no exception class is given" do
                @str.raise
                Strand.pass while @str.status
                ScratchPad.recorded.should be_kind_of(RuntimeError)
            end

            it "raises the given exception" do
                @str.raise Exception
                Strand.pass while @str.status
                ScratchPad.recorded.should be_kind_of(Exception)
            end

            it "raises the given exception with the given message" do
                @str.raise Exception, "get to work"
                Strand.pass while @str.status
                ScratchPad.recorded.should be_kind_of(Exception)
                ScratchPad.recorded.message.should == "get to work"
            end

            it "can go unhandled" do
                t = Strand.new do
                    loop {}
                end

                t.raise
                lambda {t.value}.should raise_error(RuntimeError)
            end

            it "raise the given argument even when there is an active exception" do
                raised = false
                t = Strand.new do
                    begin
                        1/0
                    rescue ZeroDivisionError
                        raised = true
                        loop { }
                    end
                end
                begin
                    raise "Create an active exception for the current strand too"
                rescue
                    Strand.pass until raised || !t.alive?
                    t.raise RangeError
                    lambda {t.value}.should raise_error(RangeError)
                end
            end

        end
    end
    #TODO find out what the spec for :kernel_raise is
    quarantine! do
        context "Strand#raise on same strand" do
            it_behaves_like :kernel_raise, :raise, Strand.current
        end
    end
end
