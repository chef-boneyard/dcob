# coding: utf-8
# frozen_string_literal: true
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "dcob/version"

Gem::Specification.new do |spec|
  spec.name          = "dcob"
  spec.version       = Dcob::VERSION
  spec.authors       = ["Adam Jacob", "Thom May", "Robb Kidd"]
  spec.email         = ["adam@chef.io", "tmay@chef.io", "rkidd@chef.io"]

  spec.summary       = "A github webhook bot that checks for the DCO"
  spec.description   = "A github webhook bot that checks for the DCO"
  spec.homepage      = "http://github.com/chef/dcob"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|config)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", ">= 12.0"
  spec.add_development_dependency "rspec", "~> 3.4"
  spec.add_development_dependency "rack-test", "~> 0.6"
  spec.add_development_dependency "webmock", "~> 2.1"
  spec.add_development_dependency "chefstyle", "~> 1.3"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "rb-readline"

  spec.add_dependency "octokit", "~> 4.3"
  spec.add_dependency "sinatra", "~> 1.4"
  spec.add_dependency "toml-rb", "~> 0.3"
  spec.add_dependency "prometheus-client", "~> 0.6"
end
