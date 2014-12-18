# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'queue_worker/version'

Gem::Specification.new do |spec|
  spec.name          = "queue_worker"
  spec.version       = QueueWorker::VERSION
  spec.authors       = ["Ryan Buckley"]
  spec.email         = ["arebuckley@gmail.com"]
  spec.summary       = %q{A light STOMP wrapper}
  spec.description   = %q{A light STOMP wrapper to ease interaction with a queueing system (e.g. ActiveMQ)}
  spec.homepage      = "https://github.com/ridiculous/queue_worker"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.1'

  spec.add_runtime_dependency 'stomp', '~> 1.3', '>= 1.3.4'
end
