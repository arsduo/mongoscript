module MongoScript
  module ORM
    module MongoidAdapter

      def database
        Mongoid::Config.database
      end

      def rehydrate(klass, data)
        Mongoid::Factory.from_db(klass, data)
      end
    end
  end
end