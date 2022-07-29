# frozen_string_literal: true

require_relative "lib/umbrellio_utils/version"

Gem::Specification.new do |spec|
  spec.name          = "umbrellio-utils"
  spec.version       = UmbrellioUtils::VERSION
  spec.authors       = ["JustAnotherDude"]
  spec.email         = ["VanyaZ158@gmail.com"]

  spec.summary       = "A set of utilities that speed up development"
  spec.description   = "UmbrellioUtils is collection of utility classes and helpers"
  spec.homepage      = "https://github.com/umbrellio/utils"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/umbrellio/utils"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/umbrellio-utils"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "memery", "~> 1"

  spec.add_development_dependency "activesupport"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "bundler-audit"
  spec.add_development_dependency "ci-helper"
  spec.add_development_dependency "nokogiri"
  spec.add_development_dependency "nori"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rspec-json_matcher"
  spec.add_development_dependency "rubocop-config-umbrellio"
  spec.add_development_dependency "semantic_logger"
  spec.add_development_dependency "sequel"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "simplecov-lcov"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "yard"
end
