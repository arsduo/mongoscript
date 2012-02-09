source 'http://rubygems.org'

# Specify your gem's dependencies in mongoscript.gemspec
gemspec

group :development do
  gem "yard"
end

group :development, :test do
  # ORM
  gem "mongoid", "~> 2.2"
  gem "bson_ext"

  # Testing infrastructure
  gem 'rspec'
  gem 'mocha'
  gem 'guard'
  gem 'guard-rspec'
  gem "parallel_tests"
  gem "fuubar"

  if RUBY_PLATFORM =~ /darwin/
    # OS X integration
    gem "ruby_gntp"
    gem "rb-fsevent", "~> 0.4.3.1"
  end
end