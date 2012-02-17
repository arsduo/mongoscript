module MongoScript
  module Multiquery

    class QueryFailedError < RuntimeError
      # The original query whose execution failed.
      attr_accessor :query_parameters
      # The name of the original query
      attr_accessor :query_name
      # The response from the multiquery Javascript.
      attr_accessor :db_response

      def initialize(name, query, response)
        @query_name = name
        @query_parameters = query
        @db_response = response
        super("Query #{@query_name} failed with the following response: #{response.inspect}")
        # set the backtrace to everything that's going on except this initialize method
        set_backtrace(caller[1...caller.length])
      end
    end

    # @private
    def self.included(base)
      base.class_eval do
        extend MongoScript::Multiquery::ClassMethods
      end
    end

    module ClassMethods

      # Runs multiple find queries at once,
      # returning the results keyed to the original query names.
      # If a query produces an error, its result will be a QueryFailedError object
      # with the appropriate details; other queries will be unaffected.
      #
      # @example
      #   MongoScript.multiquery({
      #     # simplest form -- the name is used as the collection to be queried
      #     :cars => {:query => {:_id => {$in: my_ids}}},
      #     # the name can also be arbitrary if you explicitly specify a collection
      #     # (allowing you to query the same collection twice)
      #     :my_cool_query => {:collection => :books, :objects }
      #     # you can also pass in Mongoid criteria
      #     :planes => Plane.where(manufacturer: "Boeing").sort("created_at desc").only(:_id),
      #   })
      #   => {
      #     # results get automatically turned into
      #     :cars => [#<Car: details>, #<Car: details>],
      #     :my_cool_query => [#<Book: details>],
      #     :planes =>
      #   }
      #
      #
      def multiquery(queries)
        # don't do anything if we don't get any queries
        return {} if queries == {}

        # resolve all the
        queries = normalize_queries(queries)
        results = MongoScript.execute_readonly_routine("multiquery", mongoize_queries(queries))
        process_results(results, queries)
      end


      # Standardize a set of queries into a form we can use.
      # Specifically, ensure each query has a database collection
      # and an ORM class, and resolve any ORM criteria into hashes.
      #
      # @param queries a set of query_name => hash_or_orm_criteria pairs
      #
      # @raises ArgumentError if we can't determine the DB collection or class,
      #                       or if the input isn't understood
      #
      # @returns [Hash] a set of hashes that can be fed to mongoize_queries
      #                 and later used for processing
      def normalize_queries(queries)
        # need to also ensure we have details[:klass}]
        queries = queries.dup
        queries.each_pair do |name, details|
          if details.is_a?(Hash)
            # if no collection is specified, assume it's the same as the name
            details[:collection] ||= name
            raise ArgumentError, "Unable to determine collection for query #{name}!" unless details[:collection]
          elsif processable_into_parameters?(details)
            # process Mongo ORM selectors into JS-compatible hashes
            details = queries[name] = MongoScript.build_multiquery_parameters(details)
          else
            raise ArgumentError, "Invalid selector type provided to multiquery, expected hash or Mongoid::Criteria, got #{critiera.class}"
          end

          # ensure that we know which class the collection maps to
          # so we can rehydrate the resulting data
          unless details[:klass]
            expected_class_name = details[:collection].to_s.singularize.titlecase
            raise ArgumentError, "Unable to determine class for query #{name}!" unless Object.const_defined?(expected_class_name)
            details[:klass] = Object.const_get(expected_class_name)
          end
        end
      end

      # Prepare normalized queries for use in Mongo.
      # Currently, this involves deleting parameters that can't be
      # turned into BSON.
      # (We can't act directly on the normalized queries,
      # since they contain data used later to rehydrate models.)
      #
      # @param queries previously normalized queries
      #
      # @returns [Hash] a set of queries that can be passed to MongoScript#execute
      def mongoize_queries(queries)
        # delete any information not needed by/compatible with Mongoid execution
        queries.dup.each_pair do |name, details|
          details.delete(:klass)
        end
      end

      # If any results failed, create appropriate QueryFailedError objects.
      #
      # @param results the results of the multiquery Javascript routine
      # @param queries the original queries
      #
      # @returns the multiquery results, with any error hashes replaced by proper Ruby objects
      def process_results(results, queries)
        processed_results = {}
        results.each_pair do |name, response|
          processed_results[name] = if response.is_a?(Hash) && response["error"]
            QueryFailedError.new(name, queries[name], response)
          else
            # turn all the individual responses into real objects
            response.map {|data| MongoScript.rehydrate(queries[name][:klass], data)}
          end
        end
        processed_results
      end
    end
  end
end