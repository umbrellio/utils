# frozen_string_literal: true

require "singleton"

module UmbrellioUtils
  class HTTPClient
    include Singleton

    delegate :request, :perform, :perform!, to: :client

    private

    def client
      Thread.current[:active_httpclient] ||=
        EzClient.new(
          keep_alive: 30,
          on_retry: method(:on_retry),
          timeout: 15,
        )
    end

    def on_retry(_request, error, _metadata)
      log!("Retrying on error: #{error.class}: #{error.message}")
    end

    def log!(message)
      Rails.logger.info "[httpclient] #{message}"
    end
  end
end
