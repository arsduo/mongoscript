# @private
# TBD: do we need this?
module MongoidDocumentMethods
  module ClassMethods
    def find_by_javascript(script_name, *args)
      args = args.unshift(script_name)
      # get a bunch of results via a Mongoid Javascript call,
      # then turn each hash result into a Mongoid document
      MongoScript.execute_readonly_routine(*args).map { |hash| rehydrate(self, hash) }
    end
  end
end