require 'rspec'

require 'mongoid'
require 'mongoscript'

Dir[File.join(File.dirname(__FILE__), "support", "**", "*.rb")].each {|f| load f}

RSpec.configure do |config|
  config.mock_with :mocha
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true

  config.before :each do
    database_adapter = stub("MongoDB database")
    database_adapter.stubs(:command).returns({"ok" => 1.0})
    MongoScript.stubs(:database).returns(database_adapter)
  end
end

def run_integration_tests?
  true
end

SCRIPTS_PATH = File.join(File.dirname(__FILE__), "fixtures")

# Integration testing
# Mongoid requires a RAILS_ENV to be set
if run_integration_tests?
  ENV["RACK_ENV"] ||= "test"
  Mongoid.load!(File.join(File.dirname(__FILE__), "support", "mongoid.yml"))
end