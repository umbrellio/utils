# frozen_string_literal: true

module UmbrellioUtils
  module ClickHouse
    class << self
      include Memery

      delegate :create_database, :drop_database, :config, to: :client

      def insert(table_name, db_name: self.db_name, rows: [])
        client.insert(full_table_name(table_name, db_name), rows, format: "JSONEachRow")
      end

      def from(source, db_name: self.db_name)
        ds =
          case source
          when Symbol
            DB.from(db_name == self.db_name ? SQL[source] : SQL[db_name][source])
          when nil
            DB.dataset
          else
            DB.from(source)
          end

        ds.clone(ch: true)
      end

      def execute(sql, host: nil, **opts)
        log_errors(sql) do
          client(host).execute(sql, params: opts)
        end
      end

      def query(dataset, host: nil, **opts)
        sql = sql_for(dataset)

        log_errors(sql) do
          select_all(sql, host:, **opts).map { |x| Misc::StrictHash[x.symbolize_keys] }
        end
      end

      def query_value(dataset, host: nil, **opts)
        sql = sql_for(dataset)

        log_errors(sql) do
          select_value(sql, host:, **opts)
        end
      end

      def count(dataset)
        query_value(dataset.select(SQL.ch_count))
      end

      def optimize_table!(table_name, db_name: self.db_name)
        execute("OPTIMIZE TABLE #{db_name}.#{table_name} ON CLUSTER click_cluster FINAL")
      end

      def truncate_table!(table_name, db_name: self.db_name)
        execute("TRUNCATE TABLE #{db_name}.#{table_name} ON CLUSTER click_cluster SYNC")
      end

      def drop_table!(table_name, db_name: self.db_name)
        execute("DROP TABLE #{db_name}.#{table_name} ON CLUSTER click_cluster SYNC")
      end

      def describe_table(table_name, db_name: self.db_name)
        sql = "DESCRIBE TABLE #{full_table_name(table_name, db_name)} FORMAT JSON"

        log_errors(sql) do
          select_all(sql).map { |x| Misc::StrictHash[x.symbolize_keys] }
        end
      end

      def db_name
        client.config.database.to_sym
      end

      def parse_value(value, type:)
        case type
        when /String/
          value&.to_s
        when /DateTime/
          Time.zone.parse(value) if value
        else
          value
        end
      end

      def server_version
        select_value("SELECT version()").to_f
      end

      def pg_table_connection(table)
        host = DB.opts[:host].presence || "localhost"
        port = DB.opts[:port] || 5432
        database = DB.opts[:database]
        username = DB.opts[:user]
        password = DB.opts[:password]

        Sequel.function(:postgresql, "#{host}:#{port}", database, table, username, password)
      end

      def with_temp_table(
        dataset, temp_table_name:, primary_key: [:id], primary_key_types: [:integer], **opts, &
      )
        UmbrellioUtils::Database.create_temp_table(
          nil, primary_key:, primary_key_types:, temp_table_name:, &
        )
        populate_temp_table!(temp_table_name, dataset)
        UmbrellioUtils::Database.with_temp_table(nil, primary_key:, temp_table_name:, **opts, &)
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

      def logger
        client.config.logger
      end

      def log_errors(sql)
        yield
      rescue ::ClickHouse::Error => e
        logger.error("ClickHouse error: #{e.inspect}\nSQL: #{sql}")
        raise e
      end

      def sql_for(dataset)
        unless ch_dataset?(dataset)
          raise "Non-ClickHouse dataset: #{dataset.inspect}. " \
                "You should use `CH.from` instead of `DB`"
        end

        dataset.sql
      end

      def ch_dataset?(dataset)
        case dataset
        when Sequel::Dataset
          dataset.opts[:ch] && Array(dataset.opts[:from]).all? { |x| ch_dataset?(x) }
        when Sequel::SQL::AliasedExpression
          ch_dataset?(dataset.expression)
        when Sequel::SQL::Identifier, Sequel::SQL::QualifiedIdentifier
          true
        else
          raise "Unknown dataset type: #{dataset.inspect}"
        end
      end

      def full_table_name(table_name, db_name)
        table_name = table_name.value if table_name.is_a?(Sequel::SQL::Identifier)
        "#{db_name}.#{table_name}"
      end

      def select_all(sql, host: nil, **opts)
        response = client(host).get(body: sql, query: { default_format: "JSON", **opts })
        ::ClickHouse::Response::Factory.response(response, client(host).config)
      end

      def select_value(...)
        select_all(...).first.to_a.dig(0, -1)
      end

      def populate_temp_table!(temp_table_name, dataset)
        execute(<<~SQL.squish)
          INSERT INTO TABLE FUNCTION #{DB.literal(pg_table_connection(temp_table_name))}
          #{dataset.sql}
        SQL
      end
    end
  end
end
