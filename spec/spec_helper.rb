# frozen_string_literal: true

require "bundler/setup"
require "simplecov"
require "simplecov-lcov"

SimpleCov::Formatter::LcovFormatter.config do |c|
  c.report_with_single_file = true
  c.lcov_file_name = "lcov.info"
  c.output_directory = "coverage"
end

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::LcovFormatter,
])

SimpleCov.minimum_coverage(100) if ENV["FULL_COVERAGE_CHECK"] == "true"
SimpleCov.enable_coverage(:branch)
SimpleCov.enable_coverage(:line)
SimpleCov.add_filter "spec"
SimpleCov.start

require "active_support/all"
require "umbrellio-utils"

require "nokogiri"
require "nori"
require "semantic_logger"

require "rspec/json_matcher"

Dir[Pathname(__dir__).join("support/**/*")].sort.each { |x| require(x) }

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!
  config.expose_dsl_globally = true

  config.include(RSpec::JsonMatcher)

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
