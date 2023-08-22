# frozen_string_literal: true

require "pry"

describe UmbrellioUtils::RequestWrapper do
  subject(:wrapped_request) { described_class.new(request) }

  let(:request_body) { Hash[some: "value"].to_json }
  let(:content_type) { "application/json" }
  let(:request_method) { "GET" }
  let(:query_string) { "" }
  let(:request) { ActionDispatch::TestRequest.create(request_params) }
  let(:request_params) do
    {
      "CONTENT_TYPE" => content_type,
      "REQUEST_METHOD" => request_method,
      "rack.input" => StringIO.new(request_body),
      "QUERY_STRING" => query_string,
      "REMOTE_ADDR" => "192.168.0.1",
    }
  end

  describe "#params" do
    context "with application/json content-type" do
      specify do
        expect(wrapped_request.params).to eq({ "some" => "value" })
      end

      context "with invalid json" do
        let(:request_body) { "invalid json" }

        specify do
          expect(wrapped_request.params).to eq({})
        end
      end
    end

    context "with application/xml content-type" do
      let(:content_type) { "application/xml" }
      let(:request_body) do
        "<?xml version=\"1.0\" encoding=\"UTF-8\" ?> <transaction>123</transaction>"
      end

      specify do
        expect(wrapped_request.params).to eq({ transaction: "123" })
      end

      context "with invalid xml" do
        let(:request_body) { "invalid xml" }

        specify do
          expect(wrapped_request.params).to eq({})
        end
      end
    end

    context "with content-type which ends with '+json'" do
      let(:content_type) { "application/some.domain.notification.v1+json" }

      specify do
        expect(wrapped_request.params).to eq({ "some" => "value" })
      end
    end

    context "with other content-type" do
      context "with POST method" do
        let(:content_type) { "application/x-www-form-urlencoded" }
        let(:request_body) { "txid=txid&parentTxid=parent+txid" }
        let(:request_method) { "POST" }

        specify do
          expect(wrapped_request.params).to eq({ "txid" => "txid", "parentTxid" => "parent txid" })
        end
      end

      context "with GET method" do
        let(:content_type) { nil }
        let(:query_string) { "type=deposit&status=success" }
        let(:request_body) { "" }

        specify do
          expect(wrapped_request.params).to eq({ "type" => "deposit", "status" => "success" })
        end
      end
    end
  end

  describe "#body" do
    specify do
      expect(wrapped_request.body).to eq('{"some":"value"}')
    end
  end

  describe "#[]" do
    specify do
      expect(wrapped_request["some"]).to eq("value")
    end
  end

  describe "#rails_params" do
    specify do
      expect(wrapped_request.rails_params).to eq({})
    end
  end

  describe "#raw_request" do
    specify do
      expect(wrapped_request.raw_request).to eq(request)
    end
  end

  describe "#http_headers" do
    let(:expected_headers) do
      {
        "CONTENT_LENGTH" => "0",
        "CONTENT_TYPE" => "application/json",
        "HTTPS" => "off",
        "HTTP_HOST" => "test.host",
        "HTTP_USER_AGENT" => "Rails Testing",
        "PATH_INFO" => "/",
        "QUERY_STRING" => "",
        "REMOTE_ADDR" => "192.168.0.1",
        "REQUEST_METHOD" => "GET",
        "SCRIPT_NAME" => "",
        "SERVER_NAME" => "example.org",
        "SERVER_PORT" => "80",
      }
    end

    specify do
      expect(wrapped_request.http_headers.to_h).to eq(expected_headers)
    end
  end

  describe "#path_parameters" do
    let(:request_params) do
      {
        "CONTENT_TYPE" => content_type,
        "action_dispatch.request.path_parameters" => { some: "val" },
      }
    end

    specify do
      expect(wrapped_request.path_parameters).to eq({ "some" => "val" })
    end
  end

  describe "#headers" do
    let(:expected_headers) do
      {
        "rack.multithread" => true,
        "rack.multiprocess" => true,
        "rack.run_once" => false,
        "REQUEST_METHOD" => "GET",
        "SERVER_NAME" => "example.org",
        "SERVER_PORT" => "80",
        "QUERY_STRING" => "",
        "PATH_INFO" => "/",
        "rack.url_scheme" => "http",
        "HTTPS" => "off",
      }
    end

    specify do
      expect(wrapped_request.headers.to_h).to include(expected_headers)
    end
  end

  describe "#ip" do
    specify do
      expect(wrapped_request.ip).to include("192.168.0.1")
    end
  end
end
