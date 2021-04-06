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

    def build_infinite_hash
      Hash.new { |hash, key| hash[key] = Hash.new(&hash.default_proc) }
    end
  end
end
