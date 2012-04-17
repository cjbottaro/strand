require 'spec_helper'
require 'strand/join'
require 'strand/exit'
require 'strand/wakeup'
require 'strand/status'
require 'strand/stop'
require 'strand/raise'

def quarantine!(&specs)
    #Nothing
end
include EM::SpecHelper

describe Strand do

    around(:each) do |example|
       ScratchPad.clear
       em do
           example.run
           done
       end
    end

    it "uses EM::Thread" do
        EM.reactor_running?.should be_true
        Strand.event_machine?.should be_true
        Strand.delegate_class(::Thread).should == Strand::EM::Thread
        s = Strand.new() do 
               Strand.current.should be_kind_of(Strand::EM::Thread)
            end
        s.join(1)
        done
    end


    include_examples "Strand#status"
    include_examples "Strand#exit"
    include_examples "Strand#join"
    include_examples "Strand#wakeup"
    include_examples "Strand#stop"
    include_examples "Strand#raise"

end

