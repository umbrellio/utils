# frozen_string_literal: true

module UmbrellioUtils
  module Formatting
    extend self

    def pluralize(symbol)
      symbol.to_s.pluralize.to_sym
    end

    def to_query(hash, namespace = nil)
      hash.map do |key, value|
        key = CGI.escape(key.to_s)
        ns = namespace ? "#{namespace}[#{key}]" : key
        value.is_a?(Hash) ? to_query(value, ns) : "#{CGI.escape(ns)}=#{CGI.escape(value.to_s)}"
      end.join("&")
    end

    def to_url(*parts)
      params = parts.select { |x| x.is_a?(Hash) }
      parts -= params
      params = params.reduce(&:merge)
      uri = URI.join(*parts)
      uri.query = to_query(params) if params.present?
      uri.to_s
    end

    def uncapitalize_string(string)
      string = string.dup
      string[0] = string[0].downcase
      string
    end

    def render_money(money)
      "#{money.round} #{money.currency}"
    end

    def cache_key(*parts)
      parts.flatten.compact.join("-")
    end

    def encode_key(key)
      Base64.strict_encode64(key.to_der)
    end

    def to_amount_hash(amount)
      { amount: amount.to_d, currency: amount.currency.to_s }
    end

    def to_amount_numeric(amount)
      amount.to_f
    end

    def to_amount_int(amount)
      amount.fractional.to_i
    end

    def to_amount_currency(amount)
      amount.currency.iso_code
    end

    def to_date_part_string(part)
      format("%<part>02d", part: part)
    end
  end
end
