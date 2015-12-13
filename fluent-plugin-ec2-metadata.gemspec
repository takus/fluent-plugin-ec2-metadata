# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-ec2-metadata"
  spec.version       = "0.0.8"
  spec.authors       = ["SAKAMOTO Takumi"]
  spec.email         = ["takumi.saka@gmail.com"]
  spec.description   = %q{Fluentd output plugin to add ec2 metadata fields to a event record}
  spec.summary       = %q{Fluentd output plugin to add ec2 metadata fields to a event record}
  spec.homepage      = "https://github.com/takus/fluent-plugin-ec2-metadata"
  spec.license       = "APLv2"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake"
  spec.add_development_dependency "vcr"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "test-unit", ">= 3.1.0"
  spec.add_runtime_dependency     "fluentd"
  spec.add_runtime_dependency     "aws-sdk"
end
