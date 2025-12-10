# frozen_string_literal: true

require "logger"
require "csv"
require "click_house"

config = ClickHouse.config do |config|
  config.assign(host: "localhost", database: "umbrellio_utils_test")
  config.logger = Logger.new("log/ch.log")
end

client = ClickHouse::Connection.new(config)

client.execute(<<~SQL)
  CREATE TABLE IF NOT EXISTS test (id Int32)
  ENGINE = MergeTree()
  ORDER BY id;
SQL
