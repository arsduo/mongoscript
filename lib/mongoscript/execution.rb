require 'digest/md5'

module MongoScript
  # Execute raw code on the Mongo server
  # code_for can
  # longer term, we could store functions on the server
  # and have deploy tasks that delete all and reinstall stored method on deploys
  # see http://neovintage.blogspot.com/2010/07/mongodb-stored-javascript-functions.html
  # 10gen recommends not using stored functions, but that's mainly b/c
  # they should be stored and versioned with other code
  # but a cool 6W gem for automatically clearing and installing such code would meet that objection
  # see http://www.mongodb.org/display/DOCS/Server-side+Code+Execution#Server-sideCodeExecution-Storingfunctionsserverside

  module Execution
    LOADED_SCRIPTS = {}

    class ScriptNotFound < Errno::ENOENT; end
    class NoScriptDirectory < ArgumentError; end

    class << self
      attr_accessor :script_dir
    end

    # code from stored files
    def self.code_for(script_name, dir = self.script_dir)
      script_name = script_name.to_s
      raise NoScriptDirectory, "No script_dir set for MongoScript!" unless dir
      path = File.join(dir, "#{script_name.underscore}.js")
      raise ScriptNotFound, "Unable to find script #{script_name}" unless File.exists?(path)
      code = File.read(path)
      LOADED_SCRIPTS[script_name] ||= code

      # for future extension
      # code_hash = Digest::MD5.hex_digest(code)
      # LOADED_SCRIPTS[script_name] = {
      #   :code => code,
      #   :hash => code_hash,
      #   :installed => false
      # }
      # code
    end

    def self.execute_readonly_routine(script_name, *args)
      execute_readonly_code(MongoScript.code_for(script_name), *args)
    end

    def self.execute_readwrite_routine(script_name, *args)
      execute_readwrite_code(MongoScript.code_for(script_name), *args)
    end

    # raw code
    # note: to pass in Mongo options for the $exec call, like nolock, you need to call execute directly
    # since otherwise we have no way to tell Mongo options from an argument list ending in a JS hash
    def self.execute_readonly_code(code, *args)
      # for readonly operations, set nolock to true to improve concurrency
      # http://www.mongodb.org/display/DOCS/Server-side+Code+Execution#Server-sideCodeExecution-NotesonConcurrency
      execute(code, args, {:nolock => true})
    end

    def self.execute_readwrite_code(code, *args)
      execute(code, args, options)
    end

    private

    def self.execute(code, args = [], options = {})
      # see http://mrdanadams.com/2011/mongodb-eval-ruby-driver/
      result = MongoScript.database.command({:$eval => code, args: resolve_arguments(args)}.merge(options))
      Rails.logger.warn("Mongo server-side JS didn't return okay: 1.0!  Result: #{result.inspect}") unless result["ok"] == 1.0
      result["retval"]
    end
  end
end