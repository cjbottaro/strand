require 'spec_helper'

describe "strand local variables" do
    include EM::SpecHelper

    around(:each) do |example|
        em { Strand.new() { example.run; done } }
    end

    it "should have local variables" do
        Strand.current[:name].should be_nil
        Strand.current[:name] = "a name"
        Strand.current[:name].should == "a name"
        obj = Object.new()

        Strand.current[:name] = obj
        Strand.current[:name].should equal(obj)
    end

    it "should provide #key with similar behaviour to Thread#key" do
        Strand.current.key?(:akey).should be_false
        Strand.current[:akey] = Object.new()
        Strand.current.key?(:akey).should be_true
    end

    it "should list all the keys" do
        Strand.current.keys.should =~ []
        Strand.current[:one] = "1"
        Strand.current.keys.should =~ [ :one ]
        Strand.current[:two] = 2
        Strand.current.keys.should =~ [ :one, :two ]
    end

    it "should translate strings to symbols" do
        Strand.current["first"] = 1
        Strand.current[:first].should == 1
        Strand.current["first"].should == 1
        Strand.current.key?("first").should be_true
        Strand.current.key?(:first).should be_true
        Strand.current.keys.should =~ [ :first ]
    end

end
