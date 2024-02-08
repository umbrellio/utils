# frozen_string_literal: true

module UmbrellioUtils
  module Rounding
    extend self

    SUPER_ROUND_DEFAULT_TARGETS = [1.0, 1.5, 2.5, 5.0, 10.0].freeze

    def fancy_round(number, rounding_method: :round, ugliness_level: 1)
      return 0 unless number.positive?
      log = Math.log(number, 10).floor
      coef = 2**ugliness_level
      (number * coef).public_send(rounding_method, -log) / coef.to_f
    end

    def super_round(number, rounding_method: :round, targets: SUPER_ROUND_DEFAULT_TARGETS)
      return 0 unless number.positive?

      coef = 10**Math.log(number, 10).floor
      num = number / coef.to_f

      best_diff = best_target = nil

      targets.each do |target|
        diff = target - num

        next if rounding_method == :ceil && diff.negative?
        next if rounding_method == :floor && diff.positive?

        if best_diff.nil? || diff.abs < best_diff
          best_diff = diff.abs
          best_target = target
        end
      end

      (best_target.to_d * coef).to_f
    end
  end
end
