require 'spec_helper'

describe Strand do

    include EM::SpecHelper

    it "should pass arguments resume and yield arguments like fiber" do
        em do
          s = Strand.new() do 
              # These yield args get swalled by the resume that
              # automatically starts the Strand
              Strand.yield(:y1).should == [ :r2,"r2" ]

              #These yeild args should be visible by our resume call below
              Strand.yield(:y2,"y2").should == [ "r3",:r3]
              :the_end
          end
        
          s.resume(:r2,"r2").should == [ :y2, "y2" ]

          # This is the end of the strand because there are no more yields
          # should be the value of the block.
          # Most apps should be calling value() here, rather than resume
          s.resume("r3",:r3).should == :the_end

          # the Strand is dead now, but should still have captured the value
          s.value.should == :the_end
          done 
        end
    end

end
