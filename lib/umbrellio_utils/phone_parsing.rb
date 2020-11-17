# frozen_string_literal: true

module UmbrellioUtils
  module PhoneParsing
    extend self

    def parse(*args)
      Phonelib.parse(*args)
    end

    def sanitize(string, e164_format: false)
      phone = parse(string)
      return if phone.invalid?
      return phone.e164 if e164_format

      phone.sanitized
    end
  end
end
