# frozen_string_literal: true

module UmbrellioUtils
  module Misc
    extend self

    def table_sync(scope, delay: 1, routing_key: nil)
      scope.in_batches do |batch|
        batch.each do |model|
          next if model.try(:skip_table_sync?)

          values = [model.class.name, model.values]
          publisher = TableSync::Publishing::Publisher.new(*values, confirm: false)
          publisher.routing_key = routing_key if routing_key
          publisher.publish_now
        end

        sleep delay
      end
    end

    # Ranges go from high to low priority
    def merge_ranges(*ranges)
      ranges = ranges.map { |x| x.present? && x.size == 2 ? x : [nil, nil] }
      ranges.first.zip(*ranges[1..]).map { |x| x.find(&:present?) }
    end

    #
    # Builds empty hash, which recursively returns empty hash, if key is not found.
    # Also note, that this hash and all subhashes has set #default_proc.
    # To reset this attribute use {#reset_defaults_for_hash}
    #
    # @example Dig to key
    #  h = UmbrellioUtils::Misc.build_infinite_hash => {}
    #  h.dig(:kek, :pek) => {}
    #  h => { kek: { pek: {} } }
    #
    # @return [Hash] empty infinite hash.
    #
    def build_infinite_hash
      Hash.new { |hash, key| hash[key] = Hash.new(&hash.default_proc) }
    end

    #
    # Deeply sets #default and #default_proc values to nil.
    #
    # @param [Hash] hash hash, for which you want to reset defaults.
    #
    # @return [Hash] resetted hash.
    #
    def reset_defaults_for_hash(hash)
      hash.dup.tap do |dup_hash|
        dup_hash.default = nil
        dup_hash.default_proc = nil

        dup_hash.transform_values! do |obj|
          next obj.deep_dup unless obj.is_a?(Hash)

          reset_defaults_for_hash(obj)
        end
      end
    end
  end
end
