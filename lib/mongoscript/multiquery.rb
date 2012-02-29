module MongoScript
  module Multiquery
    extend ActiveSupport::Concern

    # An error class representing Mongo queries that for some reason failed in the Javascript.
    # This error will never be raised; instead it will be returned as an object in the results array.
    class QueryFailedError < RuntimeError
      # The original query whose execution failed.
      attr_accessor :query_parameters
      # The name of the original query
      attr_accessor :query_name
      # The response from the multiquery Javascript.
      attr_accessor :db_response

      # Initialize the error, and set its backtrace.
      def initialize(name, query, response)
        @query_name = name
        @query_parameters = query
        @db_response = response
        super("Query #{@query_name} failed with the following response: #{response.inspect}")
        # set the backtrace to everything that's going on except this initialize method
        set_backtrace(caller[1...caller.length])
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
      #     :planes => #<QueryFailedError>
      #   }
      #
      # @raises ArgumentError if the input isn't valid (see #normalize_queries) (see #validate_queries!)
      #
      # @returns Hash a set of database results/errors for each query
      def multiquery(queries)
        # don't do anything if we don't get any queries
        return {} if queries == {}

        # resolve all the
        queries = normalize_queries(queries)
        validate_queries!(queries)
        results = MongoScript.execute_readonly_routine("multiquery", mongoize_queries(queries))
        process_results(results, queries)
      end

      # Standardize a set of queries into a form we can use.
      # Specifically, ensure each query has a database collection
      # and an ORM class, and resolve any ORM criteria into hashes.
      #
      # @param queries a set of query_name => hash_or_orm_criteria pairs
      #
      # @raises ArgumentError if the query details can't be processed (aren't a hash or Mongoid::Criteria)
      #
      # @returns [Hash] a set of hashes that can be fed to mongoize_queries
      #                 and later used for processing
      def normalize_queries(queries)
        # need to also ensure we have details[:klass]
        queries.inject({}) do |normalized_queries, data|
          name, details = data

          if details.is_a?(Hash)
            # duplicate the details so we don't make changes to the original query data
            details = details.dup.with_indifferent_access

            # if no collection is specified, assume it's the same as the name
            details[:collection] ||= name

            # ensure that we know which class the collection maps to
            # so we can rehydrate the resulting data
            unless details[:klass]
              expected_class_name = details[:collection].to_s.singularize.titlecase
              # if the class doesn't exist, this'll be false (and we'll raise an error later)
              details[:klass] = Object.const_defined?(expected_class_name) && Object.const_get(expected_class_name)
            end
          elsif processable_into_parameters?(details)
            # process Mongo ORM selectors into JS-compatible hashes
            details = MongoScript.build_multiquery_parameters(details)
          else
            raise ArgumentError, "Invalid selector type provided to multiquery for #{name}, expected hash or Mongoid::Criteria, got #{data.class}"
          end

          normalized_queries[name] = details
          normalized_queries.with_indifferent_access
        end
      end

      # Validate that all the queries are well formed.
      # We could do this when building them,
      # but doing it afterward allows us to present a single, comprehensive error message
      # (in case multiple queries have problems).
      #
      # @param queries a set of normalized queries
      #
      # @raises ArgumentError if any of the queries are missing Ruby class or database collection info
      #
      # @returns true if the queries are well-formatted
      def validate_queries!(queries)
        errors = {:collection => [], :klass => []}
        queries.each_pair do |name, details|
          errors[:collection] << name unless details[:collection]
          errors[:klass] << name unless details[:klass]
        end
        error_text = ""
        error_text += "Missing collection details: #{errors[:collection].join(", ")}." if errors[:collection].length > 0
        error_text += "Missing Ruby class details: #{errors[:klass].join(", ")}." if errors[:klass].length > 0
        if error_text.length > 0
          raise ArgumentError, "Unable to execute multiquery. #{error_text}"
        end
        true
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
        mongoized_queries = queries.dup
        mongoized_queries.each_pair do |name, details|
          # have to dup the query details to avoid changing the original hashes
          mongoized_queries[name] = details.dup.tap {|t| t.delete(:klass) }
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
          elsif response
            # turn all the individual responses into real objects
            response.map {|data| MongoScript.rehydrate(queries[name][:klass], data)}
          end
        end
        processed_results
      end
    end
  end
end