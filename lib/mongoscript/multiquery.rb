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
        mapped_queries = normalize_queries(queries)

        MongoScript.execute_readonly_routine("multiquery", mapped_queries)
      end

      def normalize_queries!(queries)
        queries.dup.each_pair do |name, details|
          if details.is_a?(Hash)
            # if no collection is specified, assume it's the same as the name
            details[:collection] ||= name
          else
            # process Mongo ORM selectors into JS-compatible hashes
            queries[name] = MongoScript.build_multiquery_criteria(details)
          end
        end
      end
    end
  end
end