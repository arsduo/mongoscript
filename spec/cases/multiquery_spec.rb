require 'spec_helper'

describe MongoScript::Multiquery do
  module ObjectWithMultiquery
    include MongoScript::ORM::MongoidAdapter
    include MongoScript::Execution
    include MongoScript::Multiquery
  end

  let(:results) {
    {
      :cars => 3.times.collect { Car.new.attributes },
      :canines => 3.times.collect { Car.new.attributes }
    }
  }

  let(:queries) {
    {
      :cars => {:query => {:_id => {:"$in" => [1, 2, 3]}}},
      :canines => {:collection => :dogs, :query => {:deleted_at => Time.now}}
    }
  }

  let(:normalized_queries) {
    MongoScript.normalize_queries(queries)
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

    it "normalizes the queries before validating them and passing them in for execution" do
      normalized = stub("normalized queries")
      MongoScript.stubs(:normalize_queries).with(queries, anything).returns(normalized)
      MongoScript.expects(:validate_queries!).with(normalized)
      MongoScript.expects(:execute_readonly_routine).with(anything, normalized).returns({})
      MongoScript.multiquery(queries)
    end

    it "processes the results and returns them" do
      raw_results = stub("raw_results")
      MongoScript.stubs(:execute_readonly_routine).returns(raw_results)
      MongoScript.expects(:process_results).with(raw_results, normalized_queries)
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
    it "doesn't change the underlying hash"
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

    context "when a query errors" do
      before :each do
        results[:canines] = {"error" => "ssh mongo is sleeping!"}
      end

      let(:processed_results) {
        ObjectWithMultiquery.process_results(results, normalized_queries)
      }

      let(:error) {
        processed_results[:canines]
      }

      it "turns any errors into QueryFailedErrors" do
        error.should be_a(MongoScript::Multiquery::QueryFailedError)
      end

      it "makes the normalized query available in the error" do
        error.query_parameters.should == normalized_queries[:canines]
      end

      it "identifies the query name in the error" do
        error.query_name.to_s.should == "canines"
      end

      it "makes the raw db response available in the error" do
        error.db_response.should == results[:canines]
      end
    end
  end
end