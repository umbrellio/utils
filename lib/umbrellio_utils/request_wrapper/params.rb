# frozen_string_literal: true

require "active_support/core_ext/hash/deep_merge"

module UmbrellioUtils
  class RequestWrapper
    module Params
      module HashMaterializer
        private

        def materialize_hash(value)
          convert_to_hash(value) || {}
        end

        def hash_like?(value)
          return false if value.nil?

          value.is_a?(Hash) ||
            value.respond_to?(:to_unsafe_h) ||
            (value.respond_to?(:to_h) && !value.is_a?(Array))
        end

        def convert_to_hash(value)
          raw_hash = extract_raw_hash(value)
          return unless raw_hash.is_a?(Hash)

          normalize_hash!(raw_hash)
        rescue
          {}
        end

        def extract_raw_hash(value)
          return value if value.is_a?(Hash)
          return value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
          return value.to_h if value.respond_to?(:to_h)

          value
        end

        def normalize_hash!(hash)
          hash.transform_values! { |val| materialize_value(val) }
        end

        def materialize_value(value)
          case value
          when Array
            value.map! { |val| materialize_value(val) }
          when Hash
            normalize_hash!(value)
          else
            if hash_like?(value)
              hash = extract_raw_hash(value)
              hash.is_a?(Hash) ? normalize_hash!(hash) : value
            else
              value
            end
          end
        end
      end

      module Strategies
        class JsonStrategy
          def match?(request)
            media_type = request.media_type
            media_type == "application/json" || media_type&.end_with?("+json")
          end

          def parse(request:, body:)
            _ = request
            Parsing.safely_parse_json(body.to_s)
          end
        end

        class XmlStrategy
          def initialize(remove_attributes: true)
            self.remove_attributes = remove_attributes
          end

          def match?(request)
            request.media_type == "application/xml"
          end

          def parse(request:, body:)
            _ = request
            return {} if body.blank?

            Parsing.parse_xml(body, remove_attributes:)
          rescue
            {}
          end

          private

          attr_accessor :remove_attributes
        end

        class FormStrategy
          include HashMaterializer

          def match?(request)
            !json?(request) && !xml?(request) && !request.get?
          end

          def parse(request:, body:)
            _ = body
            materialize_hash(request.POST)
          rescue
            {}
          end

          private

          def json?(request)
            JsonStrategy.new.match?(request)
          end

          def xml?(request)
            request.media_type == "application/xml"
          end
        end

        class QueryStrategy
          include HashMaterializer

          def match?(request)
            request.get?
          end

          def parse(request:, body:)
            _ = body
            materialize_hash(request.GET)
          rescue
            {}
          end
        end
      end

      class Registry
        attr_reader :strategies

        def self.default(remove_xml_attributes:)
          new([
            Strategies::JsonStrategy.new,
            Strategies::XmlStrategy.new(remove_attributes: remove_xml_attributes),
            Strategies::QueryStrategy.new,
            Strategies::FormStrategy.new,
          ])
        end

        def initialize(strategies)
          self.strategies = Array(strategies)
        end

        def first_applicable(request)
          strategies.find { |strategy| strategy.match?(request) }
        end

        def all_applicable(request)
          strategies.each_with_object([]) do |strategy, applicable|
            applicable << strategy if strategy.match?(request)
          end
        end

        def find(strategy_class)
          strategies.find { |strategy| strategy.is_a?(strategy_class) }
        end

        private

        attr_writer :strategies
      end

      class Orchestrator
        include HashMaterializer

        def initialize(mode: :single, registry: nil, xml_remove_attributes: true)
          self.mode = mode
          self.registry = registry || Registry.default(remove_xml_attributes: xml_remove_attributes)
        end

        def call(request:, body:)
          case mode
          when :single
            single_mode(request:, body:)
          when :body_plus_query
            body_plus_query_mode(request:, body:)
          else
            raise ArgumentError, "Unsupported params parsing mode: #{mode.inspect}"
          end
        end

        private

        attr_accessor :mode, :registry

        def single_mode(request:, body:)
          strategy = registry.first_applicable(request)
          return {} unless strategy

          strategy.parse(request:, body:)
        end

        def body_plus_query_mode(request:, body:)
          body_hash = parse_body(request:, body:)
          query_hash = parse_query(request:, body:)

          return query_hash if body_hash.blank?
          return body_hash if query_hash.blank?

          deep_merge_with_body_priority(body_hash, query_hash)
        end

        def parse_body(request:, body:)
          body_strategy = body_strategy_for(request)
          return {} unless body_strategy

          body_strategy.parse(request:, body:)
        end

        def parse_query(request:, body:)
          strategy = registry.find(Strategies::QueryStrategy)
          return materialize_hash(request.GET) unless strategy

          strategy.parse(request:, body:)
        end

        def body_strategy_for(request)
          registry.all_applicable(request).find do |strategy|
            !strategy.is_a?(Strategies::QueryStrategy)
          end
        end

        def deep_merge_with_body_priority(body_hash, query_hash)
          normalized_body = convert_to_hash(body_hash) || {}
          normalized_query = convert_to_hash(query_hash) || {}

          return normalized_query if normalized_body.empty?
          return normalized_body if normalized_query.empty?

          aligned_query = align_keys(normalized_body, normalized_query)

          normalized_body.deep_merge!(aligned_query) do |_key, body_value, query_value|
            merge_values(body_value, query_value)
          end

          deduplicate_keys!(normalized_body)
        end

        def merge_values(body_value, query_value)
          if body_value.is_a?(Hash) && query_value.is_a?(Hash)
            align_keys(body_value, query_value)
            body_value.deep_merge!(query_value) do |_key, nested_body, nested_query|
              merge_values(nested_body, nested_query)
            end
          elsif body_value.nil?
            query_value
          else
            body_value
          end
        end

        def deduplicate_keys!(hash)
          return hash unless hash.is_a?(Hash)

          seen = {}
          duplicates = []

          hash.each_key do |key|
            comparable = comparable_key_for(key)

            if (primary_key = seen[comparable])
              duplicates << [primary_key, key]
            else
              seen[comparable] = key
            end
          end

          duplicates.each do |primary_key, duplicate_key|
            merge_duplicate_entry!(hash, primary_key, duplicate_key)
          end

          hash.each_value { |value| deduplicate_keys!(value) if value.is_a?(Hash) }

          hash
        end

        def merge_duplicate_entry!(hash, primary_key, duplicate_key)
          duplicate_value = hash.delete(duplicate_key)
          return unless duplicate_value

          primary_value = hash[primary_key]
          hash[primary_key] = merge_values(primary_value, duplicate_value)
        end

        def align_keys(base_hash, candidate_hash)
          return candidate_hash unless base_hash.is_a?(Hash) && candidate_hash.is_a?(Hash)
          return candidate_hash if candidate_hash.empty? || base_hash.empty?

          harmonize_keys(base_hash, candidate_hash)
          harmonize_values(base_hash, candidate_hash)

          candidate_hash
        end

        def harmonize_keys(base_hash, candidate_hash)
          renames = []

          candidate_hash.each_key do |key|
            next if base_hash.key?(key)

            target_key = resolve_target_key(base_hash, key)
            renames << [key, target_key] unless target_key == key
          end

          renames.each do |original, target|
            value = candidate_hash.delete(original)
            candidate_hash[target] = value
          end
        end

        def harmonize_values(base_hash, candidate_hash)
          candidate_hash.each do |key, value|
            base_value = base_hash[key]

            if base_value.is_a?(Hash) && value.is_a?(Hash)
              align_keys(base_value, value)
            elsif base_value.is_a?(Hash) && hash_like?(value)
              nested_hash = convert_to_hash(value) || {}
              candidate_hash[key] = nested_hash
              align_keys(base_value, nested_hash)
            elsif hash_like?(value)
              candidate_hash[key] = convert_to_hash(value) || {}
            end
          end
        end

        def resolve_target_key(hash, key)
          return key if hash.key?(key)

          comparable_key = comparable_key_for(key)
          return comparable_key if hash.key?(comparable_key)

          matching_key = hash.each_key.find do |existing|
            comparable_key_for(existing) == comparable_key
          end

          matching_key || comparable_key
        end

        def comparable_key_for(key)
          key.is_a?(String) ? key : key.to_s
        end
      end
    end
  end
end
