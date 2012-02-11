module MongoScript
  module ORM
    module MongoidAdapter

      def database
        Mongoid::Config.database
      end

      def rehydrate(klass, data)
        Mongoid::Factory.from_db(klass, data)
      end

      # This resolves an array of Javascript arguments into
      # hashes that can be used with MongoScript.execute.
      # In particular, it turns Mongoid complex criteria (_id.in => ...)
      # into regular Mongo-style hashes.
      #
      # @params args an array of arguments
      #
      # @returns an array in which all hashes have been expanded.
      def resolve_arguments(args)
        args.map {|arg| arg.is_a?(Hash) ? resolve_complex_criteria(arg) : arg}
      end

      # Recursively make sure any Mongoid complex critiera (like :_id.in => ...)
      # are expanded into regular hashes (see criteria_helpers.rb in Mongoid).
      # The built-in function only goes one level in, which doesn't work
      # for hashes containing multiple levels with Mongoid helpers.
      # (Am I missing where Mongoid handles this?)
      #
      # @note this doesn't (yet) check for circular dependencies, so don't use them!
      #
      # @params hash a hash that can contain Mongo-style
      #
      # @returns a hash that maps directly to Mongo query parameters,
      #          which can be used by the Mongo DB driver
      def resolve_complex_criteria(hash)
        result = {}
        hash.expand_complex_criteria.each_pair do |k, v|
          result[k] = v.is_a?(Hash) ? resolve_complex_criteria(v) : v
        end
        result
      end
    end
  end
end