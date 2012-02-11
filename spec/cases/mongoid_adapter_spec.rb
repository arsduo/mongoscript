require 'spec_helper'

describe MongoScript::ORM::MongoidAdapter do
  class ObjectWithMongoidAdapter
    include MongoScript::ORM::MongoidAdapter
  end

  before :all do
    @adapter = ObjectWithMongoidAdapter.new
  end

  describe "#database" do
    it "returns Mongo::Config.database" do
      db_stub = stub("database")
      Mongoid::Config.stubs(:database).returns(db_stub)
      @adapter.database.should == db_stub
    end
  end

  describe "#rehydrate" do
    it "uses Mongoid::Factory to create the Mongoid doc" do
      klass = stub("class")
      hash = stub("document attributes")
      Mongoid::Factory.expects(:from_db).with(klass, hash)
      @adapter.rehydrate(klass, hash)
    end

    it "returns the rehydrated value" do
      result = stub("document")
      Mongoid::Factory.stubs(:from_db).returns(result)
      @adapter.rehydrate("foo", "bar").should == result
    end
  end

  describe "#resolve_arguments" do
    it "resolves any hashes in the arguments" do
      args = [{}, 2, 3, [], {:c.in => 2}]
      args.each {|a| @adapter.expects(:resolve_complex_criteria).with(a) if a.is_a?(Hash)}
      @adapter.resolve_arguments(args)
    end

    it "returns the mapped results" do
      args = [{}, 2, 3, [], {:c.in => 2}]
      stubby = stub("result")
      @adapter.stubs(:resolve_complex_criteria).returns(stubby)
      @adapter.resolve_arguments(args).should == args.map {|a| a.is_a?(Hash) ? stubby : a}
    end
  end

  describe "#resolve_complex_criteria" do
    it "recursively replaces any hash values with their own resolve_complex_criteria results" do
      hash = {:a.in => [1, 2], :c => {:e.exists => false, :f => {:y.ne => 2}}, :f => 3}
      @adapter.resolve_complex_criteria(hash).should ==
        {:a=>{"$in"=>[1, 2]}, :c=>{:e=>{"$exists"=>false}, :f=>{:y=>{"$ne"=>2}}}, :f=>3}
    end
  end
end