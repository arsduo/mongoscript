require 'spec_helper'

describe MongoScript::ORM::MongoidAdapter do
  module ObjectWithMongoidAdapter
    include MongoScript::ORM::MongoidAdapter
  end

  class AMongoidClass
    include Mongoid::Document
  end


  before :all do
    @adapter = ObjectWithMongoidAdapter
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

  describe "#processable_into_parameters?" do
    it "returns true for Mongoid criteria" do
      ObjectWithMongoidAdapter.processable_into_parameters?(AMongoidClass.all).should be_true
    end

    it "returns false for everything else" do
      ObjectWithMongoidAdapter.processable_into_parameters?(Hash.new).should be_false
      ObjectWithMongoidAdapter.processable_into_parameters?(Array.new).should be_false
    end
  end

  describe "#build_multiquery_parameters" do
    # this is a mishmash of stubbing and testing against the values assigned via let :)

    let(:criteria) {
      AMongoidClass.where(:_ids.in => [1, 2, 3]).only(:_id).ascending(:date).limit(4)
    }

    it "returns nil if provided something other than a Criteria" do
      ObjectWithMongoidAdapter.build_multiquery_parameters({}).should be_nil
    end

    it "doesn't change the criteria's options" do
      expect {
        ObjectWithMongoidAdapter.build_multiquery_parameters(criteria)
      }.not_to change(criteria, :options)
    end

    it "returns the selector as :selector" do
      selecty = stub("selector")
      criteria.stubs(:selector).returns(selecty)
      ObjectWithMongoidAdapter.build_multiquery_parameters(criteria)[:selector].should == selecty
    end

    it "returns the klass as :klass" do
      ObjectWithMongoidAdapter.build_multiquery_parameters(criteria)[:klass].should == AMongoidClass
    end

    it "returns the name of the collection as :collection" do
      name = stub("name")
      criteria.collection.stubs(:name).returns(name)
      ObjectWithMongoidAdapter.build_multiquery_parameters(criteria)[:collection].should == name
    end

    it "returns the fields to get as :fields" do
      ObjectWithMongoidAdapter.build_multiquery_parameters(criteria)[:fields].should == {:_id => 1, :_type => 1}
    end

    it "returns all other options as :modifiers" do
      modifiers = criteria.options.dup.delete_if {|k, v| k == :fields}
      ObjectWithMongoidAdapter.build_multiquery_parameters(criteria)[:modifiers].keys.should == modifiers.keys
    end

    it "uses Mongo::Support to expand the sort criteria" do
      sorts = stub("sorted info")
      Mongo::Support.expects(:array_as_sort_parameters).with(criteria.options[:sort]).returns(sorts)
      ObjectWithMongoidAdapter.build_multiquery_parameters(criteria)[:modifiers][:sort].should == sorts
    end

    it "works fine with no sort order" do
      ObjectWithMongoidAdapter.build_multiquery_parameters(AMongoidClass.all)[:modifiers][:sort].should == {}
    end
  end
end