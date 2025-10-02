# frozen_string_literal: true

describe UmbrellioUtils::SemanticLogger::TinyJsonFormatter do
  let(:log) do
    instance_double(SemanticLogger::Log).tap do |instance|
      allow(instance).to receive_messages(
        level: log_level,
        name: log_name,
        message: log_message,
        exception: log_exception,
        tags: log_tags,
        named_tags: log_named_tags,
        time: log_time,
        process_info: log_process_info,
      )
    end
  end
  let(:result) { formatter.call(log, nil) }

  let(:formatter) { described_class.new(**options) }
  let(:options) { Hash[custom_names_mapping:] }
  let(:custom_names_mapping) { {} }

  let(:log_level) { :debug }
  let(:log_name) { "SomeName" }
  let(:log_message) { "Some Message" }
  let(:log_exception) { nil }
  let(:log_tags) { [] }
  let(:log_named_tags) { {} }
  let(:log_time) { Time.utc(2007) }
  let(:log_process_info) { "1111-2222" }

  # md5(1111-2222) = b78cbe5f798598ea7f1ab6dc4158499d
  let(:expected_thread_fingerprint) { "b78cbe5f" }

  it "properly formats log" do
    expect(result).to be_json_as(
      severity: "DEBUG",
      name: "SomeName",
      thread_fingerprint: expected_thread_fingerprint,
      message: "Some Message",
      time: "2007-01-01T00:00:00.000000000Z",
      tags: [],
      named_tags: {},
    )
  end

  context "with custom message_size_limit" do
    let(:options) { Hash[message_size_limit: 8] }

    it "truncates message" do
      expect(result).to be_json_including(message: "Some ...")
    end

    context "with nil message" do
      let(:log_message) { nil }

      it "logs blank message" do
        expect(result).to be_json_including(message: "")
      end
    end
  end

  context "with custom field names" do
    let(:custom_names_mapping) { Hash[message: :note, time: :timestamp] }

    it "uses custom field names" do
      expect(result).to be_json_as(
        severity: "DEBUG",
        name: "SomeName",
        thread_fingerprint: expected_thread_fingerprint,
        note: "Some Message",
        timestamp: "2007-01-01T00:00:00.000000000Z",
        tags: [],
        named_tags: {},
      )
    end
  end

  context "message with some colorization" do
    let(:log_message) do
      "\e[1m\e[35mSQL (Total: 9MS, CH: 2MS)\e\e[0m SELECT \"database\"\e"
    end

    it "removes colorization" do
      expect(result).to be_json_as(
        severity: "DEBUG",
        name: "SomeName",
        thread_fingerprint: expected_thread_fingerprint,
        message: "SQL (Total: 9MS, CH: 2MS) SELECT \"database\"",
        time: "2007-01-01T00:00:00.000000000Z",
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
        thread_fingerprint: expected_thread_fingerprint,
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
        thread_fingerprint: expected_thread_fingerprint,
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
        thread_fingerprint: expected_thread_fingerprint,
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
          thread_fingerprint: expected_thread_fingerprint,
          message: "Error! (RuntimeError)\n1\n2\n3",
          time: "2007-01-01T00:00:00.000000000Z",
          tags: [],
          named_tags: {},
        )
      end
    end
  end
end
