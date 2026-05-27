# frozen_string_literal: true

require "clickhouse-native"
require_relative "../config"

module UmbrellioUtils
  module ClickHouse
    module Backends
      # Adapter for the clickhouse-native gem (TCP driver).
      #
      # Intentional differences from the HTTP-era module:
      #   - Values returned by query / query_value are real Ruby types
      #     (Time, Integer, etc.), not JSON-stringified.
      #   - The `host:` kwarg on execute / query / query_value is accepted
      #     for source compatibility but ignored — hostname is bound at
      #     Pool construction, not per query.
      class Native < Base
        SERVER_ERROR = ::ClickhouseNative::ServerError

        # Server-side error codes that mean "object doesn't exist". Used by
        # describe_table callers that want to tolerate eager-load against a
        # database that hasn't been created yet (e.g. rake ch:create).
        UNKNOWN_TABLE = 60
        UNKNOWN_DATABASE = 81

        def execute(sql, host: nil, **opts) # rubocop:disable Lint/UnusedMethodArgument
          sql_string = sql.is_a?(String) ? sql : sql.sql
          log_errors(sql_string) { pool.execute(sql_string, settings: opts) }
        end

        def query(dataset, host: nil, **opts) # rubocop:disable Lint/UnusedMethodArgument
          sql = sql_for(dataset)
          log_errors(sql) { pool.query(sql, settings: opts) }
        end

        def query_value(dataset, host: nil, **opts) # rubocop:disable Lint/UnusedMethodArgument
          sql = sql_for(dataset)
          log_errors(sql) { pool.query_value(sql, settings: opts) }
        end

        def query_each(dataset, host: nil, **opts, &) # rubocop:disable Lint/UnusedMethodArgument
          sql = sql_for(dataset)
          log_errors(sql) { pool.query_each(sql, settings: opts, &) }
        end

        def insert(table_name, db_name: self.db_name, rows: [])
          return if rows.empty?
          pool.insert(normalize_identifier(table_name), rows, db_name: db_name.to_s)
        end

        def describe_table(table_name, db_name: self.db_name)
          pool.describe_table(normalize_identifier(table_name), db_name: db_name.to_s)
        end

        def server_version
          pool.with(&:server_version).to_f
        end

        def tables
          pool.query("SHOW TABLES").pluck(:name)
        end

        def config
          ::ClickHouse.config
        end

        # Read through pool so test mocks of `pool` also redirect `db_name`.
        def db_name
          pool.database.to_sym
        end

        def logger
          @logger ||= UmbrellioUtils.config.clickhouse_native_logger ||
                      (defined?(Rails) && Rails.logger) ||
                      Logger.new($stdout)
        end

        def pool
          @pool ||= ::ClickhouseNative::Pool.new(
            **client_options(database: (config[:database] || "default").to_s),
            pool_size: Integer(config[:pool_size] || 5),
            pool_timeout: Integer(config[:pool_timeout] || 10),
            settings: UmbrellioUtils.config.clickhouse_native_settings || {},
          )
        end

        # DDL that creates/drops the configured database can't run through
        # the main pool (which is bound to that database). Open a one-shot
        # client connected to the always-present "default" db instead.
        def admin_execute(sql)
          admin = ::ClickhouseNative::Client.new(**client_options(database: "default"))
          admin.execute(sql)
        ensure
          admin&.close
        end

        private

        def client_options(database:)
          {
            host: config[:host] || "localhost",
            port: Integer(config[:port] || 9000),
            database:,
            user: (config[:username] || "default").to_s,
            password: (config[:password] || "").to_s,
            logger:,
          }
        end
      end
    end
  end
end
