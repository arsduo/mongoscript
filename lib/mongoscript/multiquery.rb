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
        mapped_queries = normalize_queries(queries)
        results = MongoScript.execute_readonly_routine("multiquery", mapped_queries)
        process_results(results, mapped_queries)
      end

      def normalize_queries(queries)
        # need to also ensure we have details[:klass}]
        queries.dup.each_pair do |name, details|
          if details.is_a?(Hash)
            # if no collection is specified, assume it's the same as the name
            details[:collection] ||= name
          elsif processable_into_parameters?(details)
            # process Mongo ORM selectors into JS-compatible hashes
            queries[name] = MongoScript.build_multiquery_parameters(details)
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