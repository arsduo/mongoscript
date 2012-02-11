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
        # don't do anything if
        return {} if queries == {}
      end
    end
  end
end