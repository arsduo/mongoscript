module MongoScript
  module Multiquery

    class QueryFailed < RuntimeError; end

    def self.included(base)
      base.class_eval do
        extend MongoScript::Multiquery::ClassMethods
      end
    end

    module ClassMethods

      def multiquery(queries)
        # don't do anything if we don't get any queries
        return {} if queries == {}

        # resolve all the
        mapped_queries = parse_queries(queries)

        MongoScript.execute_readonly_routine("multiquery", mapped_queries)
      end

      def parse_queries(queries)
        # validate that all the queries match to tables
        # and resolve any Mongoid criteria
        queries = queries.dup

        normalize_queries!(queries)
        validate_collections!(queries)

      end

      def normalize_queries!(queries)
        queries.each_pair do |name, details|
          if details.is_a?(Hash)
            # if no collection is specified, assume it's the same as the name
            details[:collection] ||= name
          else
            # process Mongo ORM selectors into JS-compatible hashes
            queries[name] = MongoScript.build_multiquery_criteria(details)
          end
        end
      end

      # Ensure that all queried collections exist.
      def validate_collections!(queries)
        collections = MongoScript.database.collections.map(&:name).map(&:to_s)
        queried_collections = queries.map {|k, details| details[:collection].to_s}.uniq
        invalid_collections = queried_collections - collections
        if invalid_collections.length > 0
          raise "Unable to determine connections all multiquery queries!  Missing collections: #{invalid_collections.join(", ")}"
        else
          true
        end
      end
    end
  end
end