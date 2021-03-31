# frozen_string_literal: true

module UmbrellioUtils
  module Formatting
    extend self

    def pluralize(symbol)
      symbol.to_s.pluralize.to_sym
    end

    def to_query(hash, namespace = nil)
      pairs = hash.map do |key, value|
        key = CGI.escape(key.to_s)
        ns = namespace ? "#{namespace}[#{key}]" : key
        value.is_a?(Hash) ? to_query(value, ns) : "#{CGI.escape(ns)}=#{CGI.escape(value.to_s)}"
      end

      pairs.join("&")
    end

    def to_url(*parts)
      params = parts.select { |x| x.is_a?(Hash) }
      parts -= params
      params = params.reduce(&:merge)
      uri = File.join(*parts)
      uri.query = to_query(params) if params.present?
      uri.to_s
    end

    def uncapitalize_string(string)
      string = string.dup
      string[0] = string[0].downcase
      string
    end

    def cache_key(*parts)
      parts.flatten.compact.join("-")
    end

    def render_money(money)
      "#{money.round} #{money.currency}"
    end

    def match_or_nil(str, regex)
      return if str.blank?
      return unless str.match?(regex)
      str
    end

    def encode_key(key)
      Base64.strict_encode64(key.to_der)
    end

    def to_date_part_string(part)
      format("%<part>02d", part: part)
    end
  end
end
