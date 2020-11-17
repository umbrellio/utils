# frozen_string_literal: true

module UmbrellioUtils
  module Checks
    extend self

    def secure_compare(src, dest)
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(src),
        ::Digest::SHA256.hexdigest(dest),
      )
    end

    def valid_email?(email)
      email =~ URI::MailTo::EMAIL_REGEXP
    end

    def between?(checked_value, boundary_values, convert_sym: :to_f)
      checked_value.public_send(convert_sym).between?(*boundary_values.first(2).map(&convert_sym))
    end
  end
end
