# frozen_string_literal: true

describe UmbrellioUtils::ClickHouse, "FINAL settings" do
  let(:ch) { described_class }
  let(:backend) { ch.backend }

  describe "#settings_for" do
    subject(:settings) { backend.send(:settings_for, dataset, opts) }

    let(:opts) { {} }

    context "with a deduplicated dataset" do
      let(:dataset) { ch.from(:test_replacing).deduplicate }

      it "disables FINAL" do
        expect(settings).to eq(final: 0)
      end

      context "when the caller passes final explicitly" do
        let(:opts) { { final: 1 } }

        it "leaves the caller's value alone" do
          expect(settings).to eq(final: 1)
        end
      end

      context "with other settings present" do
        let(:opts) { { max_threads: 2 } }

        it "keeps them" do
          expect(settings).to eq(max_threads: 2, final: 0)
        end
      end
    end

    context "with a plain dataset" do
      let(:dataset) { ch.from(:test_replacing) }

      it "adds nothing" do
        expect(settings).to eq({})
      end
    end

    context "with a raw SQL string" do
      let(:dataset) { "SELECT 1" }

      it "adds nothing" do
        expect(settings).to eq({})
      end
    end
  end

  describe "settings reaching the driver" do
    # The dataset is built before the stub: #deduplicate itself queries
    # system.tables, which would otherwise be the call that gets recorded.
    it "sends final=0 for a deduplicated query" do
      dataset = ch.from(:test_replacing).deduplicate
      allow(backend).to receive(:select_all).and_return([])
      ch.query(dataset)
      expect(backend).to have_received(:select_all).with(anything, hash_including(final: 0))
    end

    it "sends no final override for a plain query" do
      dataset = ch.from(:test_replacing)
      allow(backend).to receive(:select_all).and_return([])
      ch.query(dataset)
      expect(backend).to have_received(:select_all).with(anything, hash_not_including(:final))
    end
  end

  describe "#count" do
    before do
      ch.truncate_table!("test_replacing")
      ch.insert("test_replacing", rows: [
        { group_id: 1, id: 1, payload: "old", version: 1, is_deleted: 0 },
        { group_id: 1, id: 1, payload: "new", version: 2, is_deleted: 0 },
      ])
      ch.optimize_table!("test_replacing")
    end

    it "counts deduplicated rows once" do
      expect(ch.count(ch.from(:test_replacing).deduplicate)).to eq(1)
    end

    it "forwards settings" do
      expect(ch.count(ch.from(:test_replacing), final: 1)).to eq(1)
    end
  end
end
