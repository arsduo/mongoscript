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
    # here we just want to test the flow of the method
    # further tests ensure that each individual call works as expected
    # we also will have integration tests soon
    let(:normalized_queries) { stub("normalized queries") }
    let(:mongoized_queries)  { stub("mongoized queries") }
    let(:raw_results)        { stub("raw results") }
    let(:processed_results)  { stub("processed results") }

    before :each do
      MongoScript.stubs(:normalize_queries).returns(normalized_queries)
      MongoScript.stubs(:validate_queries!)
      MongoScript.stubs(:mongoize_queries).returns(mongoized_queries)
      MongoScript.stubs(:execute_readonly_routine).returns(raw_results)
      MongoScript.stubs(:process_results).returns(raw_results)
    end

    it "returns {} without hitting the database if passed {}" do
      MongoScript.expects(:execute).never
      MongoScript.multiquery({}).should == {}
    end

    it "normalizes the queries" do
      MongoScript.expects(:normalize_queries).with(queries)
      MongoScript.multiquery(queries)
    end

    it "validates the normalized queries" do
      MongoScript.expects(:validate_queries!).with(normalized_queries)
      MongoScript.multiquery(queries)
    end

    it "mongoizes the the normalized queries before execution" do
      MongoScript.expects(:mongoize_queries).with(normalized_queries)
      MongoScript.multiquery(queries)
    end

    it "executes the multiquery routine with the mongoized results" do
      MongoScript.expects(:execute_readonly_routine).with("multiquery", mongoized_queries).returns({})
      MongoScript.multiquery(queries)
    end

    it "processes the results and returns them" do
      MongoScript.expects(:process_results).with(raw_results, normalized_queries)
      MongoScript.multiquery(queries)
    end

    it "processes the results and returns them" do
      MongoScript.stubs(:process_results).returns(processed_results)
      MongoScript.multiquery(queries).should == processed_results
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