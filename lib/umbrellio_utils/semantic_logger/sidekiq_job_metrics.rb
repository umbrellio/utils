# frozen_string_literal: true

require_relative "../patches/active_support_event"

module UmbrellioUtils
  module SemanticLogger
    # Logs Sidekiq job duration, GC, GVL and allocation stats as a dedicated line.
    # Relies on the "perform.sidekiq_job" notification published by the umbrellio
    # fork of yabeda-sidekiq. Call +subscribe!+ from an initializer.
    module SidekiqJobMetrics
      MESSAGE = "Sidekiq job stats"

      extend self

      def subscribe!
        ActiveSupport::Notifications.subscribe("perform.sidekiq_job") do |event|
          log_event(event)
        end
      end

      private

      def log_event(event)
        logger = ::SemanticLogger[event.payload[:worker] || "Sidekiq"]
        logger.info(
          message: MESSAGE,
          duration: event.duration,
          payload: metrics_payload(event),
        )
      end

      def metrics_payload(event)
        payload = {
          worker: event.payload[:worker],
          queue: event.payload[:queue],
          **event.stats,
        }
        # [class, message] pair set by ActiveSupport::Notifications when the job raised
        payload[:exception] = event.payload[:exception] if event.payload[:exception]
        payload
      end
    end
  end
end
