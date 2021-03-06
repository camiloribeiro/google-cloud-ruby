# -*- ruby -*-
# encoding: utf-8

Gem::Specification.new do |gem|
  gem.name          = "google-cloud-monitoring"
  gem.version       = "0.21.0"

  gem.authors       = ["Google Inc"]
  gem.email         = ["googleapis-packages@google.com"]
  gem.description   = "google-cloud-monitoring is the official library for Stackdriver Monitoring."
  gem.summary       = "API Cient library for Stackdriver Monitoring"
  gem.homepage      = "http://googlecloudplatform.github.io/google-cloud-ruby/"
  gem.license       = "Apache-2.0"

  gem.platform      = Gem::Platform::RUBY

  gem.files         = `git ls-files -- lib/*`.split("\n") +
                      ["README.md", "LICENSE", ".yardopts"]
  gem.require_paths = ["lib"]

  gem.required_ruby_version = ">= 2.0.0"

  gem.add_dependency "grpc", "~> 1.0"
  gem.add_dependency "google-gax", "~> 0.6.0"
  gem.add_dependency "google-protobuf", "~> 3.0"
  gem.add_dependency "googleapis-common-protos", "~> 1.3"
end
