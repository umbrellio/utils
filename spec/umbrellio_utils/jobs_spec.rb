# frozen_string_literal: true

describe UmbrellioUtils::Jobs do
  let(:jobs) do
    Module.new do
      extend UmbrellioUtils::Jobs
    end
  end

  before do
    jobs.workers.clear
    jobs.capsules.clear
    jobs.queues.clear

    jobs.register_worker(:default)
    jobs.register_worker(:w1)

    jobs.register_capsule(:default)
    jobs.register_capsule(:cap1, weight: 5)
    jobs.register_capsule(:cap2, weight: 10)
    jobs.register_capsule(:cap3, worker: :w1)
    jobs.register_capsule(:cap4)

    jobs.register_queue(:q1, capsule: :cap1)
    jobs.register_queue(:q2, capsule: :cap2, weight: 5)
    jobs.register_queue(:q3, weight: 10)
    jobs.register_queue(:q4)
    jobs.register_queue(:q5, capsule: :cap3)
  end

  describe ".capsules_for" do
    let(:level) { "default" }
    let(:max_concurrency) { 10 }
    let(:result) { jobs.capsules_for(level, max_concurrency) }

    specify do
      expect(result).to eq(
        [
          UmbrellioUtils::Jobs::Entry.new(:default, [["q3", 10], ["q4", 1]], 1),
          UmbrellioUtils::Jobs::Entry.new(:cap1, [["q1", 1]], 3),
          UmbrellioUtils::Jobs::Entry.new(:cap2, [["q2", 5]], 6),
        ],
      )
    end

    context "non default level" do
      let(:level) { "w1" }

      specify do
        expect(result).to eq(
          [
            UmbrellioUtils::Jobs::Entry.new(:cap3, [["q5", 1]], 10),
          ],
        )
      end
    end

    context "non existent level" do
      let(:level) { "invalid" }

      specify do
        expect { result }.to raise_error('No queues found for worker "invalid"')
      end
    end
  end

  describe ".configure_capsules!" do
    before do
      allow(config).to receive(:capsule).with(:default).and_yield(capsule_default)
      allow(config).to receive(:capsule).with(:cap1).and_yield(capsule_cap1)
      allow(config).to receive(:capsule).with(:cap2).and_yield(capsule_cap2)
    end

    let(:capsule) { Struct.new(:queues, :concurrency) }
    let(:config) { double(:config) }
    let(:capsule_default) { capsule.new }
    let(:capsule_cap1) { capsule.new } # rubocop:disable RSpec/IndexedLet
    let(:capsule_cap2) { capsule.new } # rubocop:disable RSpec/IndexedLet

    specify do
      jobs.configure_capsules!(config, priority_level: "default", max_concurrency: 10)

      expect(capsule_default.queues).to eq([["q3", 10], ["q4", 1]])
      expect(capsule_default.concurrency).to eq(1)

      expect(capsule_cap1.queues).to eq([["q1", 1]])
      expect(capsule_cap1.concurrency).to eq(3)

      expect(capsule_cap2.queues).to eq([["q2", 5]])
      expect(capsule_cap2.concurrency).to eq(6)
    end

    context "non default level" do
      specify do
        jobs.configure_capsules!(config, priority_level: "w1", max_concurrency: 10)

        expect(capsule_default.queues).to eq([["q5", 1]])
        expect(capsule_default.concurrency).to eq(10)

        expect(capsule_cap1.queues).to eq(nil)
        expect(capsule_cap2.queues).to eq(nil)
      end
    end
  end

  describe ".validate_queue_name!" do
    specify do
      expect(jobs.validate_queue_name!(:q1)).to eq(nil)
    end

    specify do
      expect { jobs.validate_queue_name!(:invalid) }.to raise_error("Unknown queue: :invalid")
    end
  end

  describe ".retry_interval" do
    specify do
      expect(jobs.retry_interval(1, min_interval: 10, max_interval: 100)).to eq(10)
      expect(jobs.retry_interval(5, min_interval: 10, max_interval: 100)).to eq(17)
      expect(jobs.retry_interval(10, min_interval: 10, max_interval: 100)).to eq(63)
    end
  end
end
