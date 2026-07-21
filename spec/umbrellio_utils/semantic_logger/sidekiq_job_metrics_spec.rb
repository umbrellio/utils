# frozen_string_literal: true

require "umbrellio_utils/semantic_logger/sidekiq_job_metrics"

describe UmbrellioUtils::SemanticLogger::SidekiqJobMetrics do
  let(:logger) { instance_double(SemanticLogger::Logger) }
  let(:subscription) { described_class.subscribe! }

  before do
    allow(SemanticLogger).to receive(:[]).and_return(logger)
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
    subscription
  end

  after { ActiveSupport::Notifications.unsubscribe(subscription) }

  def instrument(payload = { worker: "SomeWorker", queue: "default" }, &block)
    block ||= proc {}
    ActiveSupport::Notifications.instrument("perform.sidekiq_job", **payload, &block)
  end

  it "logs completed job with metrics" do
    instrument

    expect(SemanticLogger).to have_received(:[]).with("SomeWorker")

    expect(logger).to have_received(:info).with(
      hash_including(
        message: "Sidekiq job stats",
        duration: be_a(Float),
        payload: {
          worker: "SomeWorker",
          queue: "default",
          gc_time: be_a(Numeric),
          gvl_time: be_a(Float),
          cpu_time: be_a(Numeric),
          idle_time: be_a(Numeric),
          allocations: be_a(Integer),
          malloc_increase_bytes: be_an(Integer),
        },
      ),
    )
  end

  it "logs a failed job at info with the exception class/message (no backtrace object)" do
    expect { instrument { raise "Boom!" } }.to raise_error("Boom!")

    expect(logger).to have_received(:info).with(
      hash_including(
        message: "Sidekiq job stats",
        payload: hash_including(exception: ["RuntimeError", "Boom!"]),
      ),
    )
    expect(logger).not_to have_received(:error)
  end

  it "omits the exception key for a successful job" do
    instrument

    expect(logger).to have_received(:info).with(
      hash_including(payload: hash_not_including(:exception)),
    )
  end

  context "when worker is not specified in the payload" do
    it "falls back to the Sidekiq logger name" do
      instrument(queue: "default")

      expect(SemanticLogger).to have_received(:[]).with("Sidekiq")
      expect(logger).to have_received(:info)
    end
  end
end
