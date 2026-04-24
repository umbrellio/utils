# frozen_string_literal: true

require "singleton"

module UmbrellioUtils
  module ClickHouse
    module Backends
      # Abstract backend. Each concrete backend (Legacy for the `click_house`
      # gem, Native for the `clickhouse-native` gem) implements the low-level
      # ops (execute / query / insert / describe_table / server_version /
      # tables / create_database / drop_database / config / logger) and a
      # SERVER_ERROR constant used by `log_errors`.
      class Base
        include Singleton

        # Concrete backends implement the low-level ops (execute / query /
        # insert / describe_table / server_version / tables / admin_execute
        # / config / logger) and define SERVER_ERROR.

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

        def count(dataset)
          query_value(dataset.select(SQL.ch_count))
        end

        def db_name
          config.database.to_sym
        end

        def create_database(name, if_not_exists: false, cluster: nil, engine: nil)
          admin_execute(
            format(
              "CREATE DATABASE %<exists>s %<name>s %<cluster>s %<engine>s",
              exists: if_not_exists ? "IF NOT EXISTS" : "",
              name:,
              cluster: cluster ? "ON CLUSTER #{cluster}" : "",
              engine: engine ? "ENGINE = #{engine}" : "",
            ),
          )
        end

        def drop_database(name, if_exists: false, cluster: nil)
          admin_execute(
            format(
              "DROP DATABASE %<exists>s %<name>s %<cluster>s",
              exists: if_exists ? "IF EXISTS" : "",
              name:,
              cluster: cluster ? "ON CLUSTER #{cluster}" : "",
            ),
          )
        end

        def truncate_table!(table_name, db_name: self.db_name)
          execute("TRUNCATE TABLE #{db_name}.#{table_name} ON CLUSTER click_cluster SYNC")
        end

        def drop_table!(table_name, db_name: self.db_name)
          execute("DROP TABLE #{db_name}.#{table_name} ON CLUSTER click_cluster SYNC")
        end

        def optimize_table!(table_name, db_name: self.db_name)
          Timeout.timeout(UmbrellioUtils.config.ch_optimize_timeout) do
            execute("OPTIMIZE TABLE #{db_name}.#{table_name} ON CLUSTER click_cluster FINAL")
          end
        end

        def parse_value(value, type:)
          case type
          when /Array/ then Array.wrap(value)
          when /DateTime/
            case value
            when String then value.present? ? Time.zone.parse(value) : nil
            else value
            end
          when /String/ then value&.to_s
          else value
          end
        end

        def pg_table_connection(table, schema: "public")
          host = ENV["PGHOST"] || DB.opts[:host].presence || "localhost"
          port = DB.opts[:port] || 5432
          # Etc.getlogin returns "root" under non-TTY shells (e.g. rake from
          # a CI runner), which is almost never a real PG role. Prefer $USER.
          login = ENV["USER"].presence || Etc.getlogin
          database = DB.opts[:database].presence || login
          username = DB.opts[:user].presence || login
          password = DB.opts[:password]
          SQL.func(:postgresql, "#{host}:#{port}", database, table, username, password, schema)
        end

        def populate_temp_table!(temp_table_name, dataset, schema: "public")
          execute(<<~SQL.squish)
            INSERT INTO TABLE FUNCTION #{DB.literal(pg_table_connection(temp_table_name, schema:))}
            #{dataset.sql}
          SQL
        end

        def with_temp_table(
          dataset, temp_table_name:, primary_key: [:id], primary_key_types: [:integer], **opts, &
        )
          unless DB.table_exists?(temp_table_name)
            UmbrellioUtils::Database.create_temp_table(
              nil, primary_key:, primary_key_types:, temp_table_name:, &
            )
            populate_temp_table!(temp_table_name, dataset)
          end
          UmbrellioUtils::Database.with_temp_table(nil, primary_key:, temp_table_name:, **opts, &)
        end

        protected

        def log_errors(sql)
          yield
        rescue self.class::SERVER_ERROR => e
          logger.error("ClickHouse error: #{e.inspect}\nSQL: #{sql}")
          raise e
        end

        def sql_for(dataset)
          return dataset if dataset.is_a?(String)
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

        def normalize_identifier(name)
          name = name.value if name.is_a?(Sequel::SQL::Identifier)
          name.to_s
        end

        def full_table_name(table_name, db_name)
          "#{db_name}.#{normalize_identifier(table_name)}"
        end
      end
    end
  end
end
