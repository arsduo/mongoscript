require 'spec_helper'

describe MongoScript::Multiquery do
  module ObjectWithMultiquery
    include MongoScript::ORM::MongoidAdapter
    include MongoScript::Execution
    include MongoScript::Multiquery
  end

  class Car; include Mongoid::Document; end
  class Dog; include Mongoid::Document; end
  let(:queries) {
    {
      :cars => {:query => {:_id => {:"$in" => [1, 2, 3]}}},
      :canines => {:collection => :dogs, :query => {:deleted_at => Time.now}}
    }
  }

  let(:results) {
    {
      :cars => [{"_id" => "abc"}, {"_id" => "def"}],
      :canines => [{"_id" => "123"}, {"_id" => "456"}]
    }
  }

  it "defines QueryFailedError error < RuntimeError" do
    MongoScript::Multiquery::QueryFailedError.superclass.should == RuntimeError
  end

  describe "#multiquery" do
    before :each do
      MongoScript.stubs(:execute_readonly_routine).returns({})
    end

    it "returns {} without hitting the database if passed {}" do
      MongoScript.expects(:execute).never
      MongoScript.multiquery({}).should == {}
    end

    it "executes the multiquery routine" do
      MongoScript.expects(:execute_readonly_routine).with("multiquery", anything).returns({})
      MongoScript.multiquery(queries)
    end

    it "normalizes the queries before passing them in" do
      normalized = stub("normalized queries")
      MongoScript.stubs(:normalize_queries).with(queries, anything).returns(normalized)
      MongoScript.expects(:execute_readonly_routine).with(anything, normalized).returns({})
      MongoScript.multiquery(queries)
    end

    it "processes the results and returns them" do
      raw_results = stub("raw_results")
      MongoScript.stubs(:execute_readonly_routine).returns(raw_results)
      MongoScript.expects(:process_results).with(raw_results, queries)
      MongoScript.multiquery(queries)
    end

    it "processes the results and returns them" do
      results = stub("results")
      MongoScript.stubs(:process_results).returns(results)
      MongoScript.multiquery(queries).should == results
    end
  end

  describe "#normalize_queries" do
    it "needs tests :("
  end

  describe "#process_results" do
    def process_results(results, queries)
      results.each_pair do |name, response|
        if response["error"]
          results[name] = QueryFailedError.new(name, queries[name], response)
        else
          # turn all the individual responses into real objects
          response.map! {|data| MongoScript.rehydrate(queries[name][:klass], data)}
        end
      end
    end

    it "rehydrates all objects" do
      normalized_queries = ObjectWithMultiquery.normalize_queries(queries)
      processed_results = ObjectWithMultiquery.process_results(results, normalized_queries)

      # in our test case, we could check to make sure that the ids match up
      # in real life, of course, there's no guarantee the database would return
      # all the objects we expect
      processed_results[:canines].each {|d| d.should be_a(Dog)}
      processed_results[:cars].each {|c| c.should be_a(Car)}
    end

    it "turns any errors into QueryFailedErrors" do
      results[:canines] = {"error" => "ssh mongo is sleeping!"}
      normalized_queries = ObjectWithMultiquery.normalize_queries(queries)
      processed_results = ObjectWithMultiquery.process_results(results, normalized_queries)

      error = processed_results[:canines]
      error.should be_a(MongoScript::Multiquery::QueryFailedError)
      error.query_parameters.should == queries[:canines]
      error.query_name.to_s.should == "canines"
      error.db_response.should == results[:canines]
    end
  end
end