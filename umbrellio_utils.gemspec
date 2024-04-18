# frozen_string_literal: true

require_relative "lib/umbrellio_utils/version"

Gem::Specification.new do |spec|
  spec.name          = "umbrellio-utils"
  spec.version       = UmbrellioUtils::VERSION
  spec.authors       = ["Team Umbrellio"]
  spec.email         = ["oss@umbrellio.biz"]

  spec.summary       = "A set of utilities that speed up development"
  spec.description   = "UmbrellioUtils is collection of utility classes and helpers"
  spec.homepage      = "https://github.com/umbrellio/utils"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.0.0")

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
end
