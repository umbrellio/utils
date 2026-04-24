# frozen_string_literal: true

module UmbrellioUtils
  # Polymorphic ClickHouse facade. The active backend is picked up from
  # `UmbrellioUtils.config.clickhouse_backend` — `:legacy` routes through
  # the `click_house` gem (HTTP), `:native` through the `clickhouse-native`
  # gem (TCP). Both backends expose the same public surface so consumer
  # code (including UmbrellioUtils::Migrations) is backend-agnostic.
  module ClickHouse
    extend self

    autoload :Backends, "umbrellio_utils/click_house/backends"

    VALID_BACKENDS = %i[legacy native].freeze

    DELEGATED = %i[
      execute query query_value query_each count insert
      from describe_table server_version tables
      create_database drop_database db_name config
      truncate_table! drop_table! optimize_table!
      parse_value pg_table_connection populate_temp_table! with_temp_table
    ].freeze

    DELEGATED.each do |method_name|
      define_method(method_name) do |*args, **kwargs, &block|
        backend.public_send(method_name, *args, **kwargs, &block)
      end
    end

    def backend
      @backend ||= backend_for(UmbrellioUtils.config.clickhouse_backend)
    end

    # Testing hook — clears the memoized backend so specs can flip
    # `clickhouse_backend` mid-run. Not part of the public API.
    def reset_backend!
      @backend = nil
    end

    private

    def backend_for(name)
      case name
      when :legacy then Backends::Legacy.instance
      when :native then Backends::Native.instance
      else raise "Unknown clickhouse_backend: #{name.inspect} (expected one of #{VALID_BACKENDS})"
      end
    end
  end
end
