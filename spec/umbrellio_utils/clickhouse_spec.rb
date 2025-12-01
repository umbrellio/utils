# frozen_string_literal: true

describe UmbrellioUtils::ClickHouse do
  let(:ch) { described_class }

  before do
    ch.truncate_table!("test")
    ch.insert("test", rows: [{ id: 1 }, { id: 2 }, { id: 3 }])
    ch.optimize_table!("test") # just for coverage
  end

  describe "#from" do
    context "with another db" do
      specify do
        expect(ch.from(:test, db_name: :test).sql).to eq(
          'SELECT * FROM "test"."test" ORDER BY rand()',
        )
      end
    end

    context "with nil" do
      specify do
        expect(ch.from(nil).sql).to eq("SELECT * ORDER BY rand()")
      end
    end

    context "with another source" do
      specify do
        expect(ch.from(ch.from(:test)).sql).to eq(
          'SELECT * FROM (SELECT * FROM "test" ORDER BY rand()) AS "t1" ORDER BY rand()'.b,
        )
      end
    end
  end

  describe "#query" do
    specify do
      query = ch.from(:test).order(:id).select(:id)
      expect(ch.query(query)).to eq([{ id: 1 }, { id: 2 }, { id: 3 }])
    end
  end

  describe "#query_value" do
    specify do
      query = ch.from(:test).order(:id).select(:id)
      expect(ch.query_value(query)).to eq(1)
    end
  end

  describe "#count" do
    specify do
      query = ch.from(:test)
      expect(ch.count(query)).to eq(3)
    end
  end

  describe "#describe_table" do
    specify do
      expect(ch.describe_table("test")).to eq(
        [
          codec_expression: "",
          comment: "",
          default_expression: "",
          default_type: "",
          name: "id",
          ttl_expression: "",
          type: "Int32",
        ],
      )
    end
  end

  describe "#db_name" do
    specify do
      expect(ch.db_name).to eq(:umbrellio_utils_test)
    end
  end

  describe "#server_version" do
    specify do
      expect(ch.server_version).to match(Numeric)
    end
  end

  describe "#with_temp_table" do
    specify do
      result = []
      dataset = ch.from(:test).order(:id)
      ch.with_temp_table(dataset, temp_table_name: "some_test_table", page_size: 1) do |batch|
        result << batch
      end
      expect(result).to eq([[3], [2], [1]])
    end
  end

  describe "#execute" do
    after { ch.drop_table!("test2") }

    specify do
      ch.execute("CREATE TABLE test2 (id Int64) ENGINE=MergeTree() ORDER BY id;")
    end
  end

  describe "#parse_value" do
    it "parses string" do
      expect(ch.parse_value("123", type: "String")).to eq("123")
    end

    it "parses nil as string" do
      expect(ch.parse_value(nil, type: "String")).to be_nil
    end

    it "parses time" do
      expect(ch.parse_value("2020-01-01", type: "DateTime")).to eq(Time.zone.parse("2020-01-01"))
    end

    it "parses integer" do
      expect(ch.parse_value(123, type: "Int32")).to eq(123)
    end
  end
end
