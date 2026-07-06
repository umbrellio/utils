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
      allocation_bytes: be_an(Integer),
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
end
