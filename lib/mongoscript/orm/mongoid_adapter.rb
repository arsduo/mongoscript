module MongoScript
  module ORM
    module MongoidAdapter

      def self.included(base)
        base.class_eval do
          extend MongoScript::ORM::MongoidAdapter::ClassMethods
        end
      end

      module ClassMethods
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

        # Turn a Mongoid::Criteria into a hash useful for
        def build_multiquery_criteria(criteria)
          if criteria.is_a?(Mongoid::Criteria)
            opts = critiera.options.dup
            # make sure the sort options are in a Mongo-compatible format
            opts[:sort] = Mongo::Support::array_as_sort_parameters(x.options[:sort] || [])
            {
              :selector => criteria.selector,
              :collection => criteria.collection.name,
              # fields are specified as a second parameter to the db[collection].find JS call
              :fields => opts[:fields],
              # everything in the options besides fields should be a modifier
              # i.e. a function that can be applied via a method to a db[collection].find query
              :modifiers => opts.tap { |o| o.delete(:fields) }
            }
          else
            raise ArgumentError, "Invalid selector type provided to multiquery, expected hash or Mongoid::Criteria, got #{critiera.class}"
          end
        end
      end
    end
  end
end