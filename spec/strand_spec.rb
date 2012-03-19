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

describe Strand do
    include EM::SpecHelper

    around(:each) do |example|
        em do
            ScratchPad.clear
            example.run
            done
        end
    end

    include_examples "Strand#status"
    include_examples "Strand#exit"
    include_examples "Strand#join"
    include_examples "Strand#wakeup"
    include_examples "Strand#stop"
    include_examples "Strand#raise"

end

