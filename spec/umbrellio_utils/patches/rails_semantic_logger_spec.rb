# frozen_string_literal: true

require "umbrellio_utils/patches/rails_semantic_logger"

describe UmbrellioUtils::Patches::RailsSemanticLogger do
  subject(:log_entry) do
    subscriber.process_action(event)
    logged_entries.last
  end

  let(:subscriber) { RailsSemanticLogger::ActionController::LogSubscriber.new }
  let(:logged_entries) { [] }

  let(:logger) do
    entries = logged_entries
    instance_double(SemanticLogger::Logger).tap do |logger|
      allow(logger).to receive(:info) { |&block| entries << block.call }
    end
  end

  let(:payload) do
    {
      action: "show",
      path: "/users/1?secret=42",
      view_runtime: 1.5,
      db_runtime: 2.25,
      headers: { "X-Some" => "header" },
      request: :request_object,
      response: :response_object,
    }
  end

  let(:event) do
    event = ActiveSupport::Notifications::Event.new(
      "process_action.action_controller", nil, nil, "42", payload
    )
    event.start!
    event.finish!
    event
  end

  before { allow(Rails).to receive(:logger).and_return(logger) }

  it "logs a simplified entry with GC, GVL and allocation stats" do
    expect(log_entry).to include(message: "Completed #show", duration: be_a(Float))

    expect(log_entry[:payload]).to include(
      action: "show",
      path: "/users/1",
      view_time: 1.5,
      db_time: 2.25,
      gc_time: be_a(Numeric),
      gvl_time: be_a(Float),
      cpu_time: be_a(Numeric),
      idle_time: be_a(Numeric),
      allocations: be_a(Integer),
      malloc_increase_bytes: be_an(Integer),
    )

    expect(log_entry[:payload].keys).not_to include(
      :headers, :request, :response, :view_runtime, :db_runtime
    )
  end

  context "without path in the payload" do
    let(:payload) { super().except(:path) }

    it "logs entry without path" do
      expect(log_entry[:payload].keys).not_to include(:path)
    end
  end

  context "with small params" do
    let(:payload) { super().merge(params: { "id" => "1" }) }

    it "keeps params as-is" do
      expect(log_entry[:payload][:params]).to eq("id" => "1")
    end
  end

  context "with params over the size limit" do
    let(:payload) { super().merge(params: { "blob" => "x" * 20_000, "id" => "1" }) }

    it "keeps a truncated preview of the values plus the size" do
      params = log_entry[:payload][:params]
      expect(params).to include(truncated: true, bytesize: be > 20_000)
      expect(params[:preview]).to start_with('{"blob":"xxx').and(end_with("..."))
      expect(params[:preview].size).to be <= (described_class::PARAMS_SIZE_LIMIT + 3)
    end
  end

  context "with a failed action" do
    let(:payload) do
      super().merge(
        exception: ["RuntimeError", "Boom!"],
        exception_object: RuntimeError.new("Boom!"),
      )
    end

    it "keeps the [class, message] pair but drops the raw exception object" do
      expect(log_entry[:payload]).to include(exception: ["RuntimeError", "Boom!"])
      expect(log_entry[:payload].keys).not_to include(:exception_object)
    end
  end
end
