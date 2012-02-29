module MongoScript
  module ORM
    module MongoidAdapter
      extend ActiveSupport::Concern

      module ClassMethods
        # The MongoDB database.
        def database
          Mongoid::Config.database
        end

        # Turn a raw hash returned by the MongoDB driver into a regular Ruby object.
        # For this adapter, it a Mongoid document.
        #
        # @param klass an ORM class that can instantiate objects from data
        # @param data raw data returned from the database
        #
        # @returns a Ruby object
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

        # Turn a Mongoid::Criteria into a hash useful for multiquery.
        #
        # @param criteria any Mongoid::Criteria object
        #
        # @returns a hash containing the extracted information ready for use in multiquery
        def build_multiquery_parameters(criteria)
          if criteria.is_a?(Mongoid::Criteria)
            opts = criteria.options.dup
            # make sure the sort options are in a Mongo-compatible format
            opts[:sort] = Mongo::Support::array_as_sort_parameters(opts[:sort] || [])
            {
              :selector => criteria.selector,
              :collection => criteria.collection.name,
              # used for rehydration
              :klass => criteria.klass,
              # fields are specified as a second parameter to the db[collection].find JS call
              :fields => opts[:fields],
              # everything in the options besides fields should be a modifier
              # i.e. a function that can be applied via a method to a db[collection].find query
              :modifiers => opts.tap { |o| o.delete(:fields) }
            }
          end
        end

        # Answers whether a given non-hash object can be turned into a hash
        # suitable for database queries.
        # Currently, it checks if the object is a Mongoid::Criteria.
        #
        # @param object the object to test
        def processable_into_parameters?(object)
          object.is_a?(Mongoid::Criteria)
        end
      end
    end
  end
end