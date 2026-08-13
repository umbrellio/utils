# frozen_string_literal: true

describe UmbrellioUtils::ClickHouse do
  let(:ch) { described_class }

  before do
    ch.truncate_table!("test_replacing")
    ch.truncate_table!("test_replacing_no_delete")
  end

  describe "#deduplicate" do
    describe "generated SQL" do
      it "wraps the source in a dedup subquery keyed on the full sorting key" do
        expect(ch.from(:test_replacing).where(group_id: 1).deduplicate.sql).to eq(
          'SELECT * FROM (SELECT * FROM "test_replacing" WHERE ("group_id" = 1) ' \
          'ORDER BY "version" DESC LIMIT 1 BY group_id, id) AS "t1" ' \
          'WHERE ("is_deleted" = 0) ORDER BY rand()',
        )
      end

      it "keeps filters chained after the boundary outside the subquery" do
        sql = ch.from(:test_replacing).where(group_id: 1).deduplicate.where(payload: "x").sql
        expect(sql).to include('WHERE ("group_id" = 1) ORDER BY "version" DESC')
        expect(sql).to end_with(
          %q{WHERE (("is_deleted" = 0) AND ("payload" = 'x')) ORDER BY rand()},
        )
      end

      it "omits the delete filter when the engine declares no is_deleted column" do
        sql = ch.from(:test_replacing_no_delete).deduplicate.sql
        expect(sql).to eq(
          'SELECT * FROM (SELECT * FROM "test_replacing_no_delete" ' \
          'ORDER BY "version" DESC LIMIT 1 BY id) AS "t1" ORDER BY rand()',
        )
      end

      it "resolves the sorting key of a Distributed table through the local table" do
        sql = ch.from(:test_replacing_distributed).where(id: 1).deduplicate.sql
        expect(sql).to include("LIMIT 1 BY group_id, id")
      end

      it "preserves the source alias so qualified references keep working" do
        ds = ch.from(Sequel[:test_replacing].as(:rows)).deduplicate
        expect(ds.sql).to include('AS "rows"')
        expect(ds.where(Sequel[:rows][:payload] => "x").sql).to include('"rows"."payload"')
      end

      it "keeps a caller's projection outside the subquery" do
        sql = ch.from(:test_replacing).select(:id).deduplicate.sql
        expect(sql).to start_with('SELECT "id" FROM (SELECT * FROM "test_replacing"')
        expect(sql).to include('WHERE ("is_deleted" = 0)')
      end

      it "orders by version first and keeps the caller's ordering as a tiebreaker" do
        sql = ch.from(:test_replacing).order(:payload).deduplicate.sql
        expect(sql).to include('ORDER BY "version" DESC, "payload" LIMIT 1 BY')
      end
    end

    describe "refusals" do
      it "refuses a joined dataset" do
        ds = ch.from(:test_replacing).join(Sequel[:test].as(:t), id: :id)
        expect { ds.deduplicate }.to raise_error(Sequel::Error, /single table source/)
      end

      it "refuses more than one source" do
        ds = ch.from(:test_replacing).from(:test_replacing, :test)
        expect { ds.deduplicate }.to raise_error(Sequel::Error, /single table source/)
      end

      it "refuses a subquery source" do
        ds = ch.from(ch.from(:test_replacing))
        expect { ds.deduplicate }.to raise_error(Sequel::Error, /single table source/)
      end

      it "refuses a non-replacing engine" do
        expect { ch.from(:test).deduplicate }
          .to raise_error(Sequel::Error, /MergeTree.*ReplacingMergeTree/)
      end

      it "refuses a Replacing table with no version column" do
        expect { ch.from(:test_replacing_no_version).deduplicate }
          .to raise_error(Sequel::Error, /declares no version column/)
      end
    end

    describe "results" do
      before do
        ch.insert("test_replacing", rows:)
        ch.optimize_table!("test_replacing")
      end

      let(:rows) do
        [
          { group_id: 1, id: 1, payload: "old", version: 1, is_deleted: 0 },
          { group_id: 1, id: 1, payload: "new", version: 2, is_deleted: 0 },
          { group_id: 1, id: 2, payload: "kept", version: 1, is_deleted: 0 },
          { group_id: 2, id: 3, payload: "gone", version: 1, is_deleted: 0 },
          { group_id: 2, id: 3, payload: "gone", version: 2, is_deleted: 1 },
        ]
      end

      it "keeps the newest version of each key and drops deleted rows" do
        query = ch.from(:test_replacing).deduplicate.order(:id).select(:id, :payload)
        expect(ch.query(query)).to eq([{ id: 1, payload: "new" }, { id: 2, payload: "kept" }])
      end

      it "matches what FINAL returns" do
        deduped = ch.query(ch.from(:test_replacing).deduplicate.order(:id).select(:id, :payload))
        final = ch.query(
          ch.from(:test_replacing).order(:id).select(:id, :payload).where(is_deleted: 0),
          final: 1,
        )
        expect(deduped).to eq(final)
      end
    end
  end
end
