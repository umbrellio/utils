# frozen_string_literal: true

namespace :ch do
  desc "run clickhouse client"
  task connect: :environment do
    cfg = UmbrellioUtils::ClickHouse.config
    params = {
      host: ENV.fetch("CLICKHOUSE_HOST", cfg.host),
      user: ENV.fetch("CLICKHOUSE_USER", cfg.username),
      password: ENV.fetch("CLICKHOUSE_PASSWORD", cfg.password),
      database: ENV.fetch("CLICKHOUSE_DATABASE", cfg.database),
      **(cfg.try(:global_params) || {}),
    }.compact_blank

    cmd = Shellwords.join(["clickhouse", "client", *params.map { |k, v| "--#{k}=#{v}" }])
    exec(cmd)
  end
end
