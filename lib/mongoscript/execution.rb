require 'digest/md5'

module MongoScript
  # Execute code on the Mongo server.

  module Execution
    extend ActiveSupport::Concern

    LOADED_SCRIPTS = {}

    class ScriptNotFound < StandardError; end
    class NoScriptDirectory < ArgumentError; end
    class ExecutionFailure < RuntimeError; end

    included do
      class << self
        attr_accessor :script_dirs
      end

      # start out with the scripts provided by the gem
      @script_dirs = [gem_path]
    end

    module ClassMethods
      # Get code from stored files.
      # This looks through each of the script directories, returning the first match it finds.
      #
      # Longer term, we could store functions on the server
      # keyed by both name and a hash of the contents (to ensure uniqueness).
      #
      # @see http://neovintage.blogspot.com/2010/07/mongodb-stored-javascript-functions.html.
      # @see http://www.mongodb.org/display/DOCS/Server-side+Code+Execution#Server-sideCodeExecution-Storingfunctionsserverside
      #
      # @note 10gen recommends not using stored functions, but that's mainly because
      #       they should be stored and versioned with other code.
      #       However, automatic installation and versioning via MD5 hashes should meet that objection.
      #
      # @param script_name the name of the script file (without .js)
      #
      # @note this is currently cached in LOADED_SCRIPTS without hashing. (To do!)
      #
      # @raises ScriptNotFound if a file with the provided basename doesn't exist in any provided directory.
      #
      # @returns the script contents
      def code_for(script_name)
        script_name = script_name.to_s.underscore
        # we can use underscore since we use ActiveSupport
        dir = @script_dirs.find {|d| File.exists?(File.join(d, "#{script_name}.js"))}
        raise ScriptNotFound, "Unable to find script #{script_name}" unless dir
        code = File.read(File.join(dir, "#{script_name}.js"))
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

      # Execute read-only code stored in a file.
      # The code will be run non-blockingly;
      # it should not contain any statements that write to the database.
      #
      # @note The name of this function may change before 1.0.
      #
      # @param script_name the name of the script file (see #code_for)
      # @param args any arguments to the function
      #
      # @returns the result of the Mongo call
      def execute_readonly_routine(script_name, *args)
        execute_readonly_code(code_for(script_name), *args)
      end

      # Execute code stored in a file that can write to the database.
      #
      # @note This call will block MongoDB, so use this method sparingly.
      #
      # @note (see #execute_readonly_routine)
      #
      # @param script_name the name of the script file (see #code_for)
      # @param args any arguments to the function
      #
      # @returns (see #execute_readonly_routine)
      def execute_readwrite_routine(script_name, *args)
        execute_readwrite_code(code_for(script_name), *args)
      end

      # raw code
      # note: to pass in Mongo options for the $exec call, like nolock, you need to call execute directly
      # since otherwise we have no way to tell Mongo options from an argument list ending in a JS hash
      def execute_readonly_code(code, *args)
        # for readonly operations, set nolock to true to improve concurrency
        # http://www.mongodb.org/display/DOCS/Server-side+Code+Execution#Server-sideCodeExecution-NotesonConcurrency
        execute(code, args, {:nolock => true})
      end

      def execute_readwrite_code(code, *args)
        execute(code, args)
      end

      def execute(code, args = [], options = {})
        # see http://mrdanadams.com/2011/mongodb-eval-ruby-driver/
        result = MongoScript.database.command({:$eval => code, :args => resolve_arguments(args)}.merge(options))
        unless result["ok"] == 1.0
          raise ExecutionFailure, "MongoScript.execute JS didn't return {ok: 1.0}!  Result: #{result.inspect}"
        end
        result["retval"]
      end

      protected

      def gem_path
        mongoscript = Bundler.load.specs.find {|s| s.name == "mongoscript"}
        File.join(mongoscript.full_gem_path, "lib", "mongoscript", "javascripts")
      end
    end
  end
end