# frozen_string_literal: true

module UmbrellioUtils
  module Misc
    extend self

    def table_sync(scope, delay: 1, routing_key: nil)
      scope.in_batches do |batch|
        batch_for_sync = batch.all.reject { |model| model.try(:skip_table_sync?) }
        next if batch_for_sync.empty?

        model_class = batch_for_sync.first.class.name
        TableSync::Publishing::Batch.new(
          object_class: model_class,
          original_attributes: batch_for_sync.map { |model| model.values },
          routing_key: routing_key,
        ).publish_now

        sleep delay
      end
    end

    #
    # Ranges go from high to low priority
    #
    def merge_ranges(*ranges)
      ranges = ranges.map { |x| x.present? && x.size == 2 ? x : [nil, nil] }
      ranges.first.zip(*ranges[1..]).map { |x| x.find(&:present?) }
    end

    #
    # Builds empty hash which recursively returns empty hash, if key is not found.
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
    # @param hash [Hash] hash for which you want to reset defaults.
    #
    # @return [Hash] reset hash.
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
