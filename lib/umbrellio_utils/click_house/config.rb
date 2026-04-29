# frozen_string_literal: true

# Provides `::ClickHouse.config` when the legacy `click_house` gem is
# not loaded. The legacy gem defines `::ClickHouse::Connection` and its
# own `::ClickHouse.config`; we only step in when it's absent (typical
# for consumers that have migrated to the `clickhouse-native` gem).
unless defined?(ClickHouse::Connection)
  module ClickHouse
    def self.config
      @config ||= Rails.application.config_for(:clickhouse)
    end
  end
end
