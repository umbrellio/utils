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

        # ClickHouse-specific dataset behaviour: string escaping plus grammar
        # Sequel's Postgres dataset doesn't know about.
        module ClickHouseDatasetMethods
          # ClickHouse uses C-style escape sequences in string literals, so
          # backslashes must be doubled. Sequel's default (Postgres) escaping
          # only escapes single-quotes.
          def literal_string_append(sql, str)
            sql << "'" << str.gsub("\\") { "\\\\" }.gsub("'", "''") << "'"
          end

          # ClickHouse `LIMIT n BY expr, ...` — keeps the first n rows per
          # distinct combination of the expressions, applied after ORDER BY.
          def limit_by(*exprs, rows: 1)
            raise Sequel::Error, "limit_by requires at least one expression" if exprs.empty?
            clone(limit_by: { exprs:, rows: })
          end

          # `LIMIT n BY` precedes the regular LIMIT/OFFSET in ClickHouse.
          def select_limit_sql(sql)
            if (limit_by = @opts[:limit_by])
              sql << " LIMIT "
              literal_append(sql, limit_by[:rows])
              sql << " BY "
              expression_list_append(sql, limit_by[:exprs])
            end

            super
          end

          # Collapse a ReplacingMergeTree's row versions by hand instead of
          # relying on the `final` setting, which merges the whole table.
          #
          # This is a boundary: everything chained BEFORE it goes inside the
          # dedup subquery, everything chained AFTER applies to the result.
          # Only immutable selectors belong before it — filtering a mutable
          # column first can match a superseded version and resurrect a row
          # that FINAL would have dropped. `is_deleted` is applied after the
          # boundary for the same reason.
          def deduplicate
            table_name, db_name = deduplication_source
            meta = ClickHouse.table_metadata(table_name, **db_name)

            unless meta.version
              raise Sequel::Error,
                    "#{table_name} declares no version column; deduplicate needs one"
            end

            inner = order(Sequel.desc(meta.version))
              .limit_by(*meta.sorting_key.map { |expr| Sequel.lit(expr) })

            wrapped = ClickHouse.from(alias_for_source ? inner.as(alias_for_source) : inner)
              .clone(ch_dedup: true)

            meta.is_deleted ? wrapped.where(meta.is_deleted => 0) : wrapped
          end

          private

          def alias_for_source
            source = Array(@opts[:from]).first
            source.alias if source.is_a?(Sequel::SQL::AliasedExpression)
          end

          # => [table_name, {} | { db_name: ... }]
          def deduplication_source
            sources = Array(@opts[:from])
            source = sources.first
            source = source.expression if source.is_a?(Sequel::SQL::AliasedExpression)

            if sources.size != 1 || @opts[:join]
              raise Sequel::Error, "deduplicate requires a single table source"
            end

            case source
            when Sequel::SQL::QualifiedIdentifier
              [source.column, { db_name: source.table }]
            when Sequel::SQL::Identifier
              [source.value, {}]
            when Symbol
              [source, {}]
            else
              raise Sequel::Error, "deduplicate requires a single table source"
            end
          end
        end

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
          ds.clone(ch: true).with_extend(ClickHouseDatasetMethods)
        end

        def count(dataset, **)
          query_value(dataset.select(SQL.ch_count), **)
        end

        # Sorting key / version / is_deleted of a ReplacingMergeTree table.
        # Distributed tables carry none of these, so they are resolved through
        # to the local table they wrap. Memoized per process, like the layout
        # it describes: a table's engine does not change under a running app.
        def table_metadata(table_name, db_name: self.db_name)
          key = [db_name.to_s, table_name.to_s]
          @table_metadata_cache ||= {}
          return @table_metadata_cache[key] if @table_metadata_cache.key?(key)

          @table_metadata_cache[key] = build_table_metadata(*key)
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

        # Returns the `ON CLUSTER <name> [SYNC]` clause for DDL, or "" if
        # `UmbrellioUtils.config.clickhouse_cluster` is blank or we're in
        # a Rails test env. Test-env suppression saves hundreds of ms per
        # DDL on a single-node CH (each ON CLUSTER op blocks waiting for
        # replicas that don't exist). The cluster *name* is still used
        # by callers like Distributed engine declarations, regardless of
        # this clause.
        def on_cluster(sync: false)
          name = UmbrellioUtils.config.clickhouse_cluster
          return "" if name.blank?
          return "" if defined?(Rails) && Rails.env.test?
          sync ? "ON CLUSTER #{name} SYNC" : "ON CLUSTER #{name}"
        end

        def truncate_table!(table_name, db_name: self.db_name)
          execute("TRUNCATE TABLE #{db_name}.#{table_name} #{on_cluster(sync: true)}")
        end

        def drop_table!(table_name, db_name: self.db_name)
          execute("DROP TABLE #{db_name}.#{table_name} #{on_cluster(sync: true)}")
        end

        def optimize_table!(table_name, db_name: self.db_name)
          Timeout.timeout(UmbrellioUtils.config.ch_optimize_timeout) do
            execute("OPTIMIZE TABLE #{db_name}.#{table_name} #{on_cluster} FINAL")
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
          dataset, temp_table_name:, primary_key: [:id], primary_key_types: [:integer], **, &
        )
          unless DB.table_exists?(temp_table_name)
            UmbrellioUtils::Database.create_temp_table(
              nil, primary_key:, primary_key_types:, temp_table_name:, &
            )
            populate_temp_table!(temp_table_name, dataset)
          end
          UmbrellioUtils::Database.with_temp_table(nil, primary_key:, temp_table_name:, **, &)
        end

        protected

        # `final` is usually a session-wide default, which would make a
        # deduplicated query merge the whole table inside its own subquery —
        # slow and redundant, since the subquery already collapses versions.
        # An explicit `final:` from the caller always wins.
        def settings_for(dataset, opts)
          return opts if opts.key?(:final)
          return opts unless dataset.is_a?(Sequel::Dataset) && dataset.opts[:ch_dedup]

          opts.merge(final: 0)
        end

        def build_table_metadata(db_name, table_name)
          row = query(
            from(:tables, db_name: :system)
              .where(database: db_name, name: table_name)
              .select(:engine, :engine_full, :sorting_key),
          ).first

          unless row
            raise ClickHouse::TableMetadata::UnknownTable, "#{db_name}.#{table_name} not found"
          end

          if row[:engine] == "Distributed"
            database, table = ClickHouse::TableMetadata.distributed_target(row[:engine_full])
            return table_metadata(table, db_name: database)
          end

          ClickHouse::TableMetadata.parse(**row)
        end

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
