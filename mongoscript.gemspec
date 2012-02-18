# -*- encoding: utf-8 -*-
require File.expand_path('../lib/mongoscript/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Alex Koppel"]
  gem.email         = ["alex+git@alexkoppel.com"]
  gem.description   = %q{An experimental Ruby library for running serverside Javascript in MongoDB.}
  gem.summary       = %q{An experimental Ruby library for running serverside Javascript in MongoDB.}
  gem.homepage      = ""

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "mongoscript"
  gem.require_paths = ["lib"]
  gem.version       = Mongoscript::VERSION

  # we use activesupport's with_indifferent_access
  gem.add_runtime_dependency(%q<activesupport>, ["~> 3.0"])
end
