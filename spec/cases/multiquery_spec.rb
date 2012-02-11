require 'spec_helper'

describe MongoScript::Multiquery do
  module ObjectWithMultiquery
    include MongoScript::ORM::MongoidAdapter
    include MongoScript::Execution
    include MongoScript::Multiquery
  end

  it "defines QueryFailed error < RuntimeError" do
    MongoScript::Multiquery::QueryFailed.superclass.should == RuntimeError
  end

  describe "#multiquery" do
    it "returns {} without hitting the database if passed {}" do
      MongoScript.expects(:execute).never
      MongoScript.multiquery({}).should == {}
    end
  end

end