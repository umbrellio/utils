# frozen_string_literal: true

require_relative "active_support_event"

module UmbrellioUtils
  module Patches
    # Simplifies the "Completed" action controller log entry and enriches it with
    # GC, GVL and allocation stats.
    # https://github.com/reidmorrison/rails_semantic_logger/blob/master/lib/rails_semantic_logger/action_controller/log_subscriber.rb # rubocop:disable Layout/LineLength
    #
    # Require this file after the rails_semantic_logger gem has been loaded
    # (e.g. from an initializer).
    module RailsSemanticLogger
      PRECISION = 6

      def process_action(event)
        ::Rails.logger.info do
          payload = event.payload.dup
          payload[:path] = extract_path(payload[:path]) if payload.key?(:path)

          payload[:view_time] = payload.delete(:view_runtime).to_f.round(PRECISION)
          payload[:db_time] = payload.delete(:db_runtime).to_f.round(PRECISION)

          payload[:gc_time] = event.gc_time.round(PRECISION)
          payload[:gvl_time] = event.gvl_time.round(PRECISION)
          payload[:cpu_time] = event.cpu_time.round(PRECISION)
          payload[:idle_time] = event.idle_time.round(PRECISION)
          payload[:allocations] = event.allocations
          payload[:allocation_bytes] = event.malloc_increase_bytes

          # Causes excessive log output with Rails 5 RC1
          payload.delete(:headers)
          # Causes recursion in Rails 6.1.rc1
          payload.delete(:request)
          payload.delete(:response)

          {
            message: "Completed ##{payload[:action]}",
            duration: event.duration,
            payload:,
          }
        end
      end
    end
  end
end

RailsSemanticLogger::ActionController::LogSubscriber.prepend(
  UmbrellioUtils::Patches::RailsSemanticLogger,
)
