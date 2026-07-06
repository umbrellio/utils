# frozen_string_literal: true

require_relative "../patches/active_support_event"

module UmbrellioUtils
  module SemanticLogger
    # Logs Sidekiq job completion with duration, GC, GVL and allocation stats.
    # Relies on the "perform.sidekiq_job" notification published by the umbrellio
    # fork of yabeda-sidekiq. Call +subscribe!+ from an initializer.
    module SidekiqJobMetrics
      PRECISION = 6

      extend self

      def subscribe!
        ActiveSupport::Notifications.subscribe("perform.sidekiq_job") do |event|
          log_event(event)
        end
      end

      private

      def log_event(event)
        logger = ::SemanticLogger[event.payload[:worker] || "Sidekiq"]
        exception = event.payload[:exception_object]

        entry = {
          message: "Completed #perform",
          duration: event.duration,
          payload: metrics_payload(event),
        }

        exception ? logger.error(exception:, **entry) : logger.info(entry)
      end

      def metrics_payload(event)
        {
          worker: event.payload[:worker],
          queue: event.payload[:queue],
          gc_time: event.gc_time.round(PRECISION),
          gvl_time: event.gvl_time.round(PRECISION),
          cpu_time: event.cpu_time.round(PRECISION),
          idle_time: event.idle_time.round(PRECISION),
          allocations: event.allocations,
          allocation_bytes: event.malloc_increase_bytes,
        }
      end
    end
  end
end
