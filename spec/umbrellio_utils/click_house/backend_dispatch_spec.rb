# frozen_string_literal: true

describe UmbrellioUtils::ClickHouse, "backend dispatch" do
  let(:facade) { described_class }

  before { facade.reset_backend! }
  after do
    facade.reset_backend!
    UmbrellioUtils.configure { |c| c.clickhouse_backend = :legacy }
  end

  context "when :legacy" do
    before { UmbrellioUtils.configure { |c| c.clickhouse_backend = :legacy } }

    it "returns the Legacy adapter" do
      expect(facade.backend).to be_a(UmbrellioUtils::ClickHouse::Backends::Legacy)
    end

    it "delegates execute to the adapter" do
      expect(facade.backend).to receive(:execute).with("SELECT 1", host: nil)
      facade.execute("SELECT 1", host: nil)
    end
  end

  context "when :native" do
    before do
      # clickhouse-native gem requires Ruby >= 3.3; gated in Gemfile.
      skip "clickhouse-native not installed" unless Gem.loaded_specs.key?("clickhouse-native")
      UmbrellioUtils.configure { |c| c.clickhouse_backend = :native }
    end

    it "returns the Native adapter" do
      expect(facade.backend).to be_a(UmbrellioUtils::ClickHouse::Backends::Native)
    end

    it "delegates query to the adapter" do
      dataset = double(sql: "SELECT 1")
      expect(facade.backend).to receive(:query).with(dataset)
      facade.query(dataset)
    end
  end

  context "when unknown" do
    before { UmbrellioUtils.configure { |c| c.clickhouse_backend = :bogus } }

    it "raises" do
      expect { facade.backend }.to raise_error(/Unknown clickhouse_backend: :bogus/)
    end
  end
end
