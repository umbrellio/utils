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
      # Hash with default field names in the output JSON.
      DEFAULT_NAMES_MAPPING = {
        severity: :severity,
        name: :name,
        thread_fingerprint: :thread_fingerprint,
        message: :message,
        tags: :tags,
        named_tags: :named_tags,
        time: :time,
      }.freeze

      # Returns a new instance of the {UmbrellioUtils::SemanticLogger::TinyJsonFormatter}.
      # @option [Integer] message_size_limit maximum number of characters in a log message
      # @option [Hash] custom_names_mapping mapping from default field names to custom ones.
      # @option custom_names_mapping [Symbol] :severity custom name for the `severity` field.
      # @option custom_names_mapping [Symbol] :name custom name for the `name` field.
      # @option custom_names_mapping [Symbol] :thread_fingerprint
      #   custom name for the thread_fingerprint field.
      # @option custom_names_mapping [Symbol] :message custom name for the `message` field.
      # @option custom_names_mapping [Symbol] :tags custom name for the `tags` field.
      # @option custom_names_mapping [Symbol] :named_tags custom name for the `named_tags` field.
      # @option custom_names_mapping [Symbol] :time custom name for the `time` field.
      # @example Use custom name for the `message` and `time` fields
      #   UmbrellioUtils::SemanticLogger::TinyJsonFormatter.new(
      #     time: :timestamp, message: :note,
      #   ) #=> <UmbrellioUtils::SemanticLogger::TinyJsonFormatter:0x000>
      # @return [UmbrellioUtils::SemanticLogger::TinyJsonFormatter]
      #   a new instance of the {UmbrellioUtils::SemanticLogger::TinyJsonFormatter}
      def initialize(message_size_limit: 10_000, custom_names_mapping: {})
        self.message_size_limit = message_size_limit
        self.field_names = { **DEFAULT_NAMES_MAPPING, **custom_names_mapping }.freeze
      end

      # Formats log structure into the JSON string.
      # @param log [SemanticLogger::Log] log's data structure.
      # @param logger [SemanticLogger::Logger] active logger.
      # @return [String] data
      def call(log, _logger)
        data = build_data_for(log)
        data.to_json
      end

      private

      # @!attribute field_names
      #   @return [Hash<Symbol, Symbol>] the mapping from default field names to the new ones.
      attr_accessor :message_size_limit, :field_names

      # Builds hash with data from log.
      # @return [Hash] the hash, which will be converted to the JSON later.
      def build_data_for(log)
        field_names.values_at(*DEFAULT_NAMES_MAPPING.keys).zip(pack_data(log)).to_h
      end

      # Builds an [Array] with all the required fields, which are arranged
      # in the order of the declaration of keys
      # in the {UmbrellioUtils::SemanticLogger::TinyJsonFormatter::DEFAULT_NAMES_MAPPING}.
      # @return [Array] an array with serialized data.
      def pack_data(log)
        [
          log.level.upcase,
          log.name,
          thread_fingerprint,
          truncate(log_to_message(log)),
          log.tags,
          log.named_tags,
          log.time.utc.iso8601(9),
        ]
      end

      # Calculates MD5 fingerprint for the thread in which the log was made.
      # @return [String] truncated `MD5` hash.
      def thread_fingerprint
        Digest::MD5.hexdigest("#{Thread.current.object_id}-#{Process.pid}")[0...8]
      end

      # Renders either exception or message of the log.
      # @return [String]
      def log_to_message(log)
        if (e = log.exception)
          msg = +"#{e.message} (#{e.class})"
          msg << "\n#{e.backtrace.join("\n")}" if e.backtrace
          msg
        else
          log.message.to_s
        end
      end

      def truncate(msg)
        return msg unless msg.size > message_size_limit

        suffix = "..."
        msg = msg[0, message_size_limit - suffix.size]

        "#{msg}#{suffix}"
      end
    end
  end
end
