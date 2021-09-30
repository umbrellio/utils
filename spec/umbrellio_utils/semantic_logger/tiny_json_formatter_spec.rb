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
      allow(instance).to receive(:named_tags).and_return(log_named_tags)
      allow(instance).to receive(:time).and_return(log_time)
    end
  end
  let(:formatter) { described_class.new }

  let(:log_level) { :debug }
  let(:log_name) { "SomeName" }
  let(:log_thread_name) { "10706" }
  let(:log_message) { "Some Message" }
  let(:log_named_tags) { Hash[] }
  let(:log_time) { Time.utc(2007) }

  it "properly formats log" do
    result = formatter.call(log, nil)

    expect(result).to be_json_as(
      severity: "DEBUG",
      name: "SomeName",
      thread_fingerprint: "85bb6139",
      message: "Some Message",
      time: "2007-01-01T00:00:00.000Z",
    )
  end
end
