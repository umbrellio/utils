# frozen_string_literal: true

module UmbrellioUtils
  module Checks
    extend self

    EMAIL_REGEXP = /\A([\w+-].?)+@[a-z\d-]+(\.[a-z]+)*\.[a-z]+\z/i
    HOLDER_NAME_REGEXP = /\A([A-Za-z0-9.'-]+ ?)+\z/

    def secure_compare(src, dest)
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(src),
        ::Digest::SHA256.hexdigest(dest),
      )
    end

    def valid_card?(number)
      numbers = number.to_s.chars.map(&:to_i)

      modified_numbers = numbers.reverse.map.with_index do |number, index|
        if index.odd?
          number *= 2
          number -= 9 if number > 9
        end

        number
      end

      (modified_numbers.sum % 10).zero?
    end

    def valid_email?(email)
      email.to_s =~ EMAIL_REGEXP
    end

    def valid_card_holder?(holder)
      holder.to_s =~ HOLDER_NAME_REGEXP
    end

    def valid_card_cvv?(cvv)
      cvv = cvv.to_s.scan(/\d/).join
      cvv.size.between?(3, 4)
    end

    def valid_phone?(phone)
      Phonelib.valid?(phone)
    end

    def between?(checked_value, boundary_values, convert_sym: :to_f)
      checked_value.public_send(convert_sym).between?(*boundary_values.first(2).map(&convert_sym))
    end

    def int_array?(value, size_range = 1..Float::INFINITY)
      value.all? { |value| value.to_i.positive? } && value.size.in?(size_range)
    end

    def valid_limit?(limit)
      int_array?(limit, 2..2) && limit.reduce(:<=)
    end
  end
end
