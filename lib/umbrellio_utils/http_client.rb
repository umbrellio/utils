# frozen_string_literal: true

require "singleton"

module UmbrellioUtils
  class HTTPClient
    include Singleton

    def perform(*args, **kwargs)
      client.perform(*args, **kwargs)
    end

    def perform!(*args, **kwargs)
      client.perform!(*args, **kwargs)
    end

    def request(*args, **kwargs)
      client.request(*args, **kwargs)
    end

    private

    def client
      Thread.current[UmbrellioUtils.config.http_client_name] ||= EzClient.new(**ezclient_options)
    end

    def ezclient_options
      { keep_alive: 30, on_retry: method(:on_retry), timeout: 15 }
    end

    def on_retry(_request, error, _metadata)
      log!("Retrying on error: #{error.class}: #{error.message}")
    end

    def log!(message)
      Rails.logger.info "[httpclient] #{message}"
    end
  end
end
