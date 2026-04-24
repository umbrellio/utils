# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in umbrellio_utils.gemspec
gemspec

gem "activesupport"
gem "bundler"
gem "ci-helper"
gem "click_house", github: "umbrellio/click_house", branch: "master"
# clickhouse-native requires Ruby >= 3.3; gate so 3.1/3.2 CI still bundles.
install_if -> { Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.3.0") } do
  gem "clickhouse-native"
end
gem "csv"
gem "http"
gem "net-pop"
gem "nokogiri"
gem "nori"
gem "pg"
gem "pry"
gem "rake"
gem "rspec"
gem "rspec-json_matcher"
gem "rubocop-config-umbrellio"
gem "semantic_logger"
gem "sequel"
gem "sequel-batches"
gem "simplecov"
gem "simplecov-lcov"
gem "table_sync"
gem "timecop"
gem "yard"
