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
      PARAMS_SIZE_LIMIT = 10_000

      def process_action(event)
        ::Rails.logger.info do
          payload = event.payload.dup
          payload[:path] = extract_path(payload[:path]) if payload.key?(:path)
          payload[:params] = cap_params(payload[:params]) if payload.key?(:params)

          payload[:view_time] = payload.delete(:view_runtime).to_f.round(PRECISION)
          payload[:db_time] = payload.delete(:db_runtime).to_f.round(PRECISION)
          payload.merge!(event.stats)

          # Causes excessive log output with Rails 5 RC1
          payload.delete(:headers)
          # Causes recursion in Rails 6.1.rc1
          payload.delete(:request)
          payload.delete(:response)
          # Keep only the [class, message] pair in :exception (set by ActiveSupport),
          # not the raw exception with its backtrace — consistent with sidekiq_job_metrics.
          payload.delete(:exception_object)

          {
            message: "Completed ##{payload[:action]}",
            duration: event.duration,
            payload:,
          }
        end
      end

      private

      def cap_params(params)
        serialized = params.to_json
        return params if serialized.bytesize <= PARAMS_SIZE_LIMIT

        {
          truncated: true,
          bytesize: serialized.bytesize,
          preview: "#{serialized[0, PARAMS_SIZE_LIMIT]}...",
        }
      end
    end
  end
end

RailsSemanticLogger::ActionController::LogSubscriber.prepend(
  UmbrellioUtils::Patches::RailsSemanticLogger,
)
