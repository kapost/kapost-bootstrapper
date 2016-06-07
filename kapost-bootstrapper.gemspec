# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kapost/bootstrapper/version'

Gem::Specification.new do |spec|
  spec.name          = "kapost-bootstrapper"
  spec.version       = Kapost::Bootstrapper::VERSION
  spec.authors       = ["Paul Sadauskas"]
  spec.email         = ["paul@sadauskas.com"]

  spec.summary       = %q{A small helper utility for your app to declare and setup its system dependencies}
  spec.homepage      = "https://github.com/kapost/kapost-bootstrapper"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
