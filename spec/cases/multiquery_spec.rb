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
    it "doesn't change the underlying hash" do
      expect {
        MongoScript.normalize_queries(queries)
        # inspect will display all info inside the hash
        # a good proxy to make sure inside values don't change
      }.not_to change(queries, :inspect)
    end

    context "for hashes" do
      let(:normalized_queries) { MongoScript.normalize_queries(queries) }

      context "determining collection" do
        it "derives the collection from the name if none is provided" do
          queries[:cars].delete(:collection)
          # normalized_query isn't executed until we call it,
          # so the changes to queries are respected
          normalized_queries[:cars][:collection].to_s.should == "cars"
        end

        it "leaves the collection alone if it's provided" do
          queries[:canines][:collection] = :dogs
          normalized_queries[:canines][:collection].to_s.should == queries[:canines][:collection].to_s
        end

        it "checks with indifferent access" do
          queries[:canines].delete(:collection)
          queries[:canines]["collection"] = :dogs
          normalized_queries[:canines][:collection].to_s.should == queries[:canines]["collection"].to_s
        end
      end

      context "determining the class" do
        it "uses the klass entry if it's provided" do
          queries[:cars][:klass] = Car
          normalized_queries[:cars][:klass].should == Car
        end

        it "derives the klass (if not provided) from the specified collection (if provided)" do
          queries[:cars].delete(:klass)
          queries[:cars][:collection] = :cars
          normalized_queries[:cars][:klass].should == Car
        end

        it "derives the klass (if not provided) from the collection (derived from name)" do
          queries[:cars].delete(:klass)
          queries[:cars].delete(:collection)
          normalized_queries[:cars][:klass].should == Car
        end

        it "sets klass to false if the klass can't be determined from the collection" do
          queries[:canines].delete(:collection)
          queries[:canines].delete(:klass)
          Object.const_defined?("Canine").should be_false
          normalized_queries[:canines][:klass].should be_false
        end
      end
    end

    context "for objects processable into queries" do
      let(:sample_query) {
        {
          :cars => stub("Mongoid or other object"),
          :canines => stub("another object"),
          :hashy => {:query_type => :hash}
        }.with_indifferent_access
      }

      before :each do
        MongoScript.stubs(:processable_into_parameters?).returns(true)
      end

      it "sees if it's processable" do
        MongoScript.stubs(:build_multiquery_parameters)
        sample_query.values.each do |val|
          unless val.is_a?(Hash)
            MongoScript.expects(:processable_into_parameters?).with(val).returns(true)
          else
            MongoScript.expects(:processable_into_parameters?).with(val).never
          end
        end
        MongoScript.normalize_queries(sample_query)
      end

      it "returns the processed values" do
        # ensure that non-hash values are processed...
        sample_query.inject({}) do |return_vals, (key, val)|
          unless val.is_a?(Hash)
            MongoScript.expects(:build_multiquery_parameters).with(val).returns("my stub value for #{key}")
          end
        end
        # ...and returned appropriately
        MongoScript.normalize_queries(sample_query).each do |k, v|
          unless sample_query[k].is_a?(Hash)
            v.should == "my stub value for #{k}"
          end
        end
      end
    end

    context "for objects not processable into queries" do
      let(:sample_query) {
        {
          :cars => stub("Mongoid or other object"),
          :canines => stub("another object"),
          :hashy => {:query_type => :hash}
        }.with_indifferent_access
      }

      it "throws an ArgumentError" do
        MongoScript.stubs(:processable_into_parameters?).returns(false)
        expect { MongoScript.normalize_queries(sample_query) }.to raise_exception(ArgumentError)
      end
    end
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