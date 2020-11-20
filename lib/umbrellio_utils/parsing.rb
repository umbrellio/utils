# frozen_string_literal: true

module UmbrellioUtils
  module Parsing
    extend self

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

    def parse_xml(xml, remove_attributes: true, snakecase: true)
      xml = Nokogiri::XML(xml)
      xml.remove_namespaces!
      xml.xpath("//@*").remove if remove_attributes

      tags_converter = snakecase ? -> (tag) { tag.snakecase.to_sym } : -> (tag) { tag.to_sym }
      nori = Nori.new(convert_tags_to: tags_converter, convert_dashes_to_underscores: snakecase)
      nori.parse(xml.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION))
    end
  end
end
