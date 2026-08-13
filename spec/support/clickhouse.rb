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

# ReplacingMergeTree with a multi-column sorting key, a version column and an
# is_deleted column — the shape `#deduplicate` has to introspect.
client.execute(<<~SQL)
  CREATE TABLE IF NOT EXISTS test_replacing
  (group_id Int32, id Int32, payload String, version Int32, is_deleted UInt8)
  ENGINE = ReplacingMergeTree(version, is_deleted)
  ORDER BY (group_id, id);
SQL

# Distributed tables carry no sorting key of their own, so metadata lookup has
# to resolve through to the local table.
client.execute(<<~SQL)
  CREATE TABLE IF NOT EXISTS test_replacing_distributed
  (group_id Int32, id Int32, payload String, version Int32, is_deleted UInt8)
  ENGINE = Distributed('click_cluster', 'umbrellio_utils_test', 'test_replacing', id);
SQL
