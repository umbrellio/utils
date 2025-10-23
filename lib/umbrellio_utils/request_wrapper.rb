# frozen_string_literal: true

require_relative "request_wrapper/params"

module UmbrellioUtils
  class RequestWrapper
    include Memery

    def initialize(request, remove_xml_attributes: true, params_mode: :single, params_registry: nil)
      self.request = request
      self.remove_xml_attributes = remove_xml_attributes
      self.default_params_mode = params_mode
      self.custom_params_registry = params_registry
    end

    def params(mode: default_params_mode)
      params_cache[mode] ||= orchestrator_for(mode).call(request:, body:)
    end

    def merged_params
      params(mode: :body_plus_query)
    end

    memoize def body
      request.body.rewind
      request_body = request.body.read.dup.force_encoding("utf-8")
      request.body.rewind
      request_body
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

    def headers
      request.headers
    end

    def ip
      request.ip
    end

    private

    attr_accessor :request, :remove_xml_attributes, :default_params_mode, :custom_params_registry

    def params_cache
      @params_cache ||= {}
    end

    def orchestrators
      @orchestrators ||= {}
    end

    def orchestrator_for(mode)
      orchestrators[mode] ||= Params::Orchestrator.new(
        mode:,
        registry: params_registry,
        xml_remove_attributes: remove_xml_attributes,
      )
    end

    def params_registry
      custom_params_registry || default_registry
    end

    memoize def default_registry
      Params::Registry.default(remove_xml_attributes: remove_xml_attributes)
    end
  end
end
