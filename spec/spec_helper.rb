require 'rspec'

require 'mongoid'
require 'mongoscript'

RSpec.configure do |config|
  config.mock_with :mocha
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
end

SCRIPTS_PATH = File.join(File.dirname(__FILE__), "fixtures")