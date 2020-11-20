# frozen_string_literal: true

module UmbrellioUtils
  class RequestWrapper
    include Memery

    delegate :headers, :ip, to: :request

    def initialize(request)
      self.request = request
    end

    memoize def params
      parse_params
    end

    memoize def body
      request.body.read.dup.force_encoding("utf-8")
    end

    def [](key)
      params[key]
    end

    def rails_params
      request.params
    end

    def raw_request
      request
    end

    memoize def http_headers
      headers = request.headers.select do |key, _value|
        key.start_with?("HTTP_") || key.in?(ActionDispatch::Http::Headers::CGI_VARIABLES)
      end

      HTTP::Headers.coerce(headers.sort)
    end

    memoize def path_parameters
      request.path_parameters.except(:controller, :action).stringify_keys
    end

    private

    attr_accessor :request

    def parse_params
      case request.content_type
      when "application/json"
        Parsing.safely_parse_json(body)
      when "application/xml"
        Parsing.parse_xml(body)
      else
        request.get? ? request.GET : request.POST
      end
    end
  end
end
