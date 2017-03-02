# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'circuit_breaker/version'

Gem::Specification.new do |spec|
  spec.name          = "circuit_breaker"
  spec.version       = CircuitBreaker::VERSION
  spec.authors       = ["Anthony Ross"]
  spec.email         = ["anthony.s.ross@gmail.com"]

  spec.summary       = %q{Circuit Breaker pattern}
  spec.description   = %q{The Circuit Breaker pattern is used to prevent constant fail-over from spotty remote systems}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.metadata["yard.run"] = "yri"

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry", "~> 0.10"
  spec.add_development_dependency "timecop", "~> 0.8"
  spec.add_development_dependency "simplecov", "~> 0.13"
  spec.add_development_dependency "yard", "~> 0.9"
  spec.add_development_dependency "redis", "~> 3.3"
end
