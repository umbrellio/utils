# frozen_string_literal: true

namespace :ch do
  desc "run clickhouse client"
  task connect: :environment do
    params = {
      host: ENV.fetch("CLICKHOUSE_HOST", UmbrellioUtils::ClickHouse.config.host),
      user: ENV.fetch("CLICKHOUSE_USER", UmbrellioUtils::ClickHouse.config.username),
      password: ENV.fetch("CLICKHOUSE_PASSWORD", UmbrellioUtils::ClickHouse.config.password),
      database: ENV.fetch("CLICKHOUSE_DATABASE", UmbrellioUtils::ClickHouse.config.database),
      **UmbrellioUtils::ClickHouse.config.global_params,
    }.compact_blank

    cmd = Shellwords.join(["clickhouse", "client", *params.map { |k, v| "--#{k}=#{v}" }])
    exec(cmd)
  end
end
