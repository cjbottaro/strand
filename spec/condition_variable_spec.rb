require 'spec_helper'
require 'condition_variable/broadcast'
require 'condition_variable/signal'
require 'condition_variable/wait'

def quarantine!(&specs)
    #Nothing
end

describe Strand::ConditionVariable do
    include EM::SpecHelper

    around(:each) do |example|
        em do
            ScratchPad.clear
            example.run
            done
        end
    end

    include_examples "ConditionVariable#signal"
    include_examples "ConditionVariable#wait"
    include_examples "ConditionVariable#broadcast"

end

