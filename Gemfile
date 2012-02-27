source 'http://rubygems.org'

# Specify your gem's dependencies in mongoscript.gemspec
gemspec

group :development do
  gem "yard"
end

group :development, :test do
  # ORM
  gem "mongoid", "~> 2.3.0"
  # mongo & bson 1.6 generate invalid gemspecs in rbx
  gem "mongo", "~> 1.5.0"
  if defined? JRUBY_VERSION
    gem "bson"
  else
    gem "bson_ext", "~> 1.5.0"
  end

  # Testing infrastructure
  gem 'rake'
  gem 'rspec'
  gem 'mocha'
  gem 'guard'
  gem 'guard-rspec'
  gem "parallel_tests"
  gem "fuubar"
  gem "rake"

  # testing bundled Javascripts
  gem "jasmine"

  if RUBY_PLATFORM =~ /darwin/
    # OS X integration
    gem "ruby_gntp"
    gem "rb-fsevent", "~> 0.4.3.1"
  end
end