# frozen_string_literal: true

require "singleton"
require "delegate"

module UmbrellioUtils
  class HTTPClient < Delegator
    include Singleton

    def __getobj__
      Thread.current[UmbrellioUtils.config.http_client_name] ||=
        EzClient.new(
          keep_alive: 30,
          on_retry: method(:on_retry),
          timeout: 15,
        )
    end

    private

    def on_retry(_request, error, _metadata)
      log!("Retrying on error: #{error.class}: #{error.message}")
    end

    def log!(message)
      Rails.logger.info "[httpclient] #{message}"
    end
  end
end
