# frozen_string_literal: true

describe UmbrellioUtils::SemanticLogger::TinyJsonFormatter do
  before { stub_const("UmbrellioUtils::SemanticLogger::TinyJsonFormatter::Process", process_stub) }

  let(:process_stub) do
    class_double(Process).tap do |klass|
      allow(klass).to receive(:pid).and_return(process_pid)
    end
  end
  let(:process_pid) { 1234 }

  let(:log) do
    instance_double(SemanticLogger::Log).tap do |instance|
      allow(instance).to receive(:level).and_return(log_level)
      allow(instance).to receive(:name).and_return(log_name)
      allow(instance).to receive(:thread_name).and_return(log_thread_name)
      allow(instance).to receive(:message).and_return(log_message)
      allow(instance).to receive(:exception).and_return(log_exception)
      allow(instance).to receive(:tags).and_return(log_tags)
      allow(instance).to receive(:named_tags).and_return(log_named_tags)
      allow(instance).to receive(:time).and_return(log_time)
    end
  end
  let(:result) { formatter.call(log, nil) }

  let(:formatter) { described_class.new(custom_names_mapping:) }
  let(:custom_names_mapping) { Hash[] }

  let(:log_level) { :debug }
  let(:log_name) { "SomeName" }
  let(:log_thread_name) { "10706" }
  let(:log_message) { "Some Message" }
  let(:log_exception) { nil }
  let(:log_tags) { [] }
  let(:log_named_tags) { Hash[] }
  let(:log_time) { Time.utc(2007) }

  it "properly formats log" do
    expect(result).to be_json_as(
      severity: "DEBUG",
      name: "SomeName",
      thread_fingerprint: "85bb6139",
      message: "Some Message",
      time: "2007-01-01T00:00:00.000000000Z",
      tags: [],
      named_tags: {},
    )
  end

  context "with custom field names" do
    let(:custom_names_mapping) { Hash[message: :note, time: :timestamp] }

    it "uses custom field names" do
      expect(result).to be_json_as(
        severity: "DEBUG",
        name: "SomeName",
        thread_fingerprint: "85bb6139",
        note: "Some Message",
        timestamp: "2007-01-01T00:00:00.000000000Z",
        tags: [],
        named_tags: {},
      )
    end
  end

  context "with invalid mapping" do
    let(:custom_names_mapping) { Hash[kek: :pek] }

    it "ignores this fields" do
      expect(result).to be_json_as(
        severity: "DEBUG",
        name: "SomeName",
        thread_fingerprint: "85bb6139",
        message: "Some Message",
        time: "2007-01-01T00:00:00.000000000Z",
        tags: [],
        named_tags: {},
      )
    end
  end

  context "with active tags" do
    let(:log_tags) { ["kek"] }
    let(:log_named_tags) { Hash[id: "very-long-id"] }

    it "properly renders this tags" do
      expect(result).to be_json_as(
        severity: "DEBUG",
        name: "SomeName",
        thread_fingerprint: "85bb6139",
        message: "Some Message",
        time: "2007-01-01T00:00:00.000000000Z",
        tags: ["kek"],
        named_tags: { id: "very-long-id" },
      )
    end
  end

  context "with exception" do
    let(:log_exception) { RuntimeError.new("Error!") }

    it "renders exception" do
      expect(result).to be_json_as(
        severity: "DEBUG",
        name: "SomeName",
        thread_fingerprint: "85bb6139",
        message: "Error! (RuntimeError)",
        time: "2007-01-01T00:00:00.000000000Z",
        tags: [],
        named_tags: {},
      )
    end

    context "exception with a backtrace" do
      before { log_exception.set_backtrace(%w[1 2 3]) }

      it "renders exception with backtrace" do
        expect(result).to be_json_as(
          severity: "DEBUG",
          name: "SomeName",
          thread_fingerprint: "85bb6139",
          message: "Error! (RuntimeError)\n1\n2\n3",
          time: "2007-01-01T00:00:00.000000000Z",
          tags: [],
          named_tags: {},
        )
      end
    end
  end
end
