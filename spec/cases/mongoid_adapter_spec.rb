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
end