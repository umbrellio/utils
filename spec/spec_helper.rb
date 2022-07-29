# frozen_string_literal: true

require "simplecov"
require "simplecov-lcov"

SimpleCov::Formatter::LcovFormatter.config do |config|
  config.report_with_single_file = true
  config.single_report_path = "coverage/lcov.info"
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

require "bundler/setup"

require "active_support/all"
require "nokogiri"
require "nori"
require "rspec/json_matcher"
require "semantic_logger"
require "sequel"
require "timecop"

require "umbrellio-utils"

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

  config.before(:suite) do
    Time.zone = "UTC"
  end

  config.around do |spec|
    if spec.metadata[:db]
      DB.transaction(rollback: :always, &spec)
    else
      spec.call
    end
  end

  config.order = :random
  Kernel.srand config.seed
end
