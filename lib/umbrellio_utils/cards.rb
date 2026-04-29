# frozen_string_literal: true

module UmbrellioUtils
  module Cards
    extend self

    class InvalidExpiryDateString < StandardError
    end

    def parse_expiry_date!(string, **)
      result = parse_expiry_date(string, **)

      unless result
        raise InvalidExpiryDateString, "Failed to parse expiry date: #{string.inspect}"
      end

      result
    end

    def parse_expiry_date(string)
      month, year = string.split("/", 2).map(&:to_i)
      return unless month && year
      year += 2000 if year < 100
      time = suppress(ArgumentError) { Time.zone.local(year, month) }
      time + 1.month - 1.second if time
    end
  end
end
