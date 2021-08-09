# frozen_string_literal: true

module UmbrellioUtils
  module Parsing
    extend self

    RFC_AUTH_HEADERS = %w[
      HTTP_AUTHORIZATION
      HTTP_X_HTTP_AUTHORIZATION
      HTTP_REDIRECT_X_HTTP_AUTHORIZATION
    ].freeze
    CARD_TRUNCATED_PAN_REGEX = /\A(\d{6}).*(\d{4})\z/.freeze

    def try_to_parse_as_json(data)
      JSON.parse(data) rescue data
    end

    def parse_xml(xml, remove_attributes: true, snakecase: true)
      xml = Nokogiri::XML(xml)
      xml.remove_namespaces!
      xml.xpath("//@*").remove if remove_attributes

      tags_converter = snakecase ? -> (tag) { tag.snakecase.to_sym } : -> (tag) { tag.to_sym }
      nori = Nori.new(convert_tags_to: tags_converter, convert_dashes_to_underscores: false)
      nori.parse(xml.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION))
    end

    def card_truncated_pan(string)
      string.gsub(CARD_TRUNCATED_PAN_REGEX, "\\1...\\2")
    end

    def card_expiry_time(string, year_format: "%y")
      format_string = "%m/#{year_format}"
      time = suppress(ArgumentError) { Time.zone.strptime(string, format_string) }
      time + 1.month - 1.second if time
    end

    def extract_host(string)
      URI(string).host
    end

    def parse_basic_auth(headers)
      auth_header = headers.values_at(*RFC_AUTH_HEADERS).compact.first or return
      credentials_b64 = auth_header[/\ABasic (.*)/, 1] or return
      joined_credentials = Base64.strict_decode64(credentials_b64) rescue return

      joined_credentials.split(":")
    end

    def safely_parse_base64(string)
      Base64.strict_decode64(string)
    rescue ArgumentError
      nil
    end

    def safely_parse_json(string)
      JSON.parse(string)
    rescue JSON::ParserError
      {}
    end

    def parse_datetime(timestamp, timezone: "UTC", format: nil)
      return if timestamp.blank?
      tz = ActiveSupport::TimeZone[timezone]
      format ? tz.strptime(timestamp, format) : tz.parse(timestamp)
    end

    def sanitize_phone(string, e164_format: false)
      phone = Phonelib.parse(string)
      return if phone.invalid?
      return phone.e164 if e164_format

      phone.sanitized
    end
  end
end
