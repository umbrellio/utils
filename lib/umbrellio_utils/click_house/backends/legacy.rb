# frozen_string_literal: true

require "click_house"

module UmbrellioUtils
  module ClickHouse
    module Backends
      # Adapter for the umbrellio/click_house gem (HTTP driver).
      class Legacy < Base
        include Memery

        SERVER_ERROR = ::ClickHouse::Error

        def execute(sql, host: nil, **opts)
          log_errors(sql) { client(host).execute(sql, params: opts) }
        end

        def query(dataset, host: nil, **opts)
          sql = sql_for(dataset)
          log_errors(sql) do
            select_all(sql, host:, **opts).map { |x| Misc::StrictHash[x.symbolize_keys] }
          end
        end

        def query_value(dataset, host: nil, **opts)
          sql = sql_for(dataset)
          log_errors(sql) { select_value(sql, host:, **opts) }
        end

        def query_each(dataset, host: nil, **opts, &)
          query(dataset, host:, **opts).each(&)
        end

        def insert(table_name, db_name: self.db_name, rows: [])
          client.insert(full_table_name(table_name, db_name), rows, format: "JSONEachRow")
        end

        def describe_table(table_name, db_name: self.db_name)
          sql = "DESCRIBE TABLE #{full_table_name(table_name, db_name)} FORMAT JSON"
          log_errors(sql) { select_all(sql).map { |x| Misc::StrictHash[x.symbolize_keys] } }
        end

        def server_version
          select_value("SELECT version()").to_f
        end

        def tables
          client.tables
        end

        # Legacy HTTP driver can issue DDL directly; no admin side-channel
        # needed. Base#create_database / #drop_database call this.
        def admin_execute(sql)
          client.execute(sql)
        end

        def config
          client.config
        end

        def logger
          client.config.logger
        end

        private

        def client(host = nil)
          cfg = ::ClickHouse.config
          cfg.host = resolve(host) if host
          ::ClickHouse::Connection.new(cfg)
        end
        memoize :client, ttl: 1.minute

        def resolve(host)
          IPSocket.getaddress(host)
        rescue => e
          Exceptions.notify!(e, raise_errors: false)
          config.host
        end

        def select_all(sql, host: nil, **opts)
          response = client(host).get(body: sql, query: { default_format: "JSON", **opts })
          ::ClickHouse::Response::Factory.response(response, client(host).config)
        end

        def select_value(...)
          select_all(...).first.to_a.dig(0, -1)
        end
      end
    end
  end
end
