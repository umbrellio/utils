# frozen_string_literal: true

module UmbrellioUtils
  # Namespace for the differrent appenders and formatters for the SemanticLogger library.
  # @see https://logger.rocketjob.io/ Semantic Logger documentation.
  module SemanticLogger
    # Simple JSON formatter, represented as callable object.
    # @example Using of formatter
    #   formatter = UmbrellioUtils::SemanticLogger::TinyJsonFormatter.new
    #   SemanticLogger.add_appender(io: $stdout, formatter: formatter)
    class TinyJsonFormatter
      # Formats log structure into the JSON string.
      # @param log [SemanticLogger::Log] log's data structure.
      # @param logger [SemanticLogger::Logger] active logger.
      # @return [String] data
      def call(log, _logger)
        data = build_data_for(log)
        data.to_json
      end

      private

      # Builds hash with data from log.
      # @private
      def build_data_for(log)
        {
          severity: log.level.upcase,
          name: log.name,
          thread_fingerprint: thread_fingerprint_for(log),
          message: log.message,
          tags: log.named_tags,
          time: log.time.utc.iso8601(3),
        }
      end

      # Calculates MD5 fingerprint for the thread, in which the log was made.
      # @private
      def thread_fingerprint_for(log)
        Digest::MD5.hexdigest("#{log.thread_name}#{Process.pid}")[0...8]
      end
    end
  end
end
