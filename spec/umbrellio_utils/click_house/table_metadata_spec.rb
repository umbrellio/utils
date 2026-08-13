# frozen_string_literal: true

describe UmbrellioUtils::ClickHouse::TableMetadata do
  describe ".parse" do
    def parse(engine_full, sorting_key: "id")
      engine = engine_full[/\A\w+/]
      described_class.parse(engine:, engine_full:, sorting_key:)
    end

    it "reads version and is_deleted from ReplacingMergeTree" do
      meta = parse("ReplacingMergeTree(version, is_deleted) ORDER BY id")
      expect(meta.version).to eq(:version)
      expect(meta.is_deleted).to eq(:is_deleted)
    end

    it "reads a version-only ReplacingMergeTree" do
      meta = parse("ReplacingMergeTree(version) ORDER BY id")
      expect(meta.version).to eq(:version)
      expect(meta.is_deleted).to be_nil
    end

    it "handles ReplacingMergeTree without arguments" do
      meta = parse("ReplacingMergeTree PARTITION BY toYYYYMM(created_at) ORDER BY id")
      expect(meta.version).to be_nil
      expect(meta.is_deleted).to be_nil
    end

    it "skips the zookeeper path and replica of ReplicatedReplacingMergeTree" do
      meta = parse(
        "ReplicatedReplacingMergeTree('/clickhouse/tables/{shard}/db/t', '{replica}', " \
        "updated_at, is_deleted) PARTITION BY toYYYYMM(created_at) ORDER BY id",
      )
      expect(meta.version).to eq(:updated_at)
      expect(meta.is_deleted).to eq(:is_deleted)
    end

    it "handles a replicated version-only table" do
      meta = parse(
        "ReplicatedReplacingMergeTree('/tables/{shard}/t', '{replica}', ver) ORDER BY id",
      )
      expect(meta.version).to eq(:ver)
      expect(meta.is_deleted).to be_nil
    end

    it "handles a replicated table with no replacing arguments" do
      meta = parse("ReplicatedReplacingMergeTree('/tables/{shard}/t', '{replica}') ORDER BY id")
      expect(meta.version).to be_nil
      expect(meta.is_deleted).to be_nil
    end

    it "splits a sorting key containing function calls" do
      meta = parse(
        "ReplacingMergeTree(v) ORDER BY id",
        sorting_key: "toYYYYMM(created_at), project_id, player_id, id",
      )
      expect(meta.sorting_key).to eq(
        ["toYYYYMM(created_at)", "project_id", "player_id", "id"],
      )
    end

    it "treats an empty sorting key as no columns" do
      expect(parse("ReplacingMergeTree(v) ORDER BY id", sorting_key: "").sorting_key).to eq([])
    end

    it "reports a non-replacing engine without version columns" do
      meta = parse("MergeTree PARTITION BY toYYYYMM(created_at) ORDER BY id")
      expect(meta).to have_attributes(
        engine: "MergeTree", replacing?: false, version: nil, is_deleted: nil,
      )
      expect(meta.sorting_key).to eq(%w[id])
    end

    it "does not treat a parenthesis inside a quoted argument as structure" do
      meta = parse(
        "ReplicatedReplacingMergeTree('/clickhouse/tables/{shard}/db)/t', '{replica}', " \
        "version, is_deleted) ORDER BY id",
      )
      expect(meta.version).to eq(:version)
      expect(meta.is_deleted).to eq(:is_deleted)
    end
  end

  describe ".distributed_target" do
    it "extracts database and table from a Distributed engine" do
      expect(
        described_class.distributed_target(
          "Distributed('click_cluster', 'unetsafe', 'external_operations', order_id)",
        ),
      ).to eq(%w[unetsafe external_operations])
    end

    it "handles a Distributed engine without a sharding key" do
      expect(described_class.distributed_target("Distributed('cluster', 'db', 'tbl')"))
        .to eq(%w[db tbl])
    end
  end
end

describe UmbrellioUtils::ClickHouse do
  let(:ch) { described_class }

  describe "#table_metadata" do
    it "reads a local ReplacingMergeTree table" do
      meta = ch.table_metadata(:test_replacing)
      expect(meta.sorting_key).to eq(%w[group_id id])
      expect(meta.version).to eq(:version)
      expect(meta.is_deleted).to eq(:is_deleted)
    end

    it "resolves a Distributed table to its local table" do
      expect(ch.table_metadata(:test_replacing_distributed))
        .to eq(ch.table_metadata(:test_replacing))
    end

    it "raises for an unknown table" do
      expect { ch.table_metadata(:no_such_table_here) }
        .to raise_error(described_class::TableMetadata::UnknownTable, /no_such_table_here/)
    end

    it "answers the sorting key of a non-replacing table" do
      meta = ch.table_metadata(:test)
      expect(meta).to have_attributes(engine: "MergeTree", replacing?: false)
      expect(meta.sorting_key).to eq(%w[id])
    end
  end
end
