# frozen_string_literal: true

require "stringio"

describe UmbrellioUtils::ClickHouse do
  let(:deprecations) { StringIO.new }
  let(:dataset) { described_class.from(:a) }

  around do |example|
    previous_output = Sequel::Deprecation.output
    Sequel::Deprecation.output = deprecations
    example.run
  ensure
    Sequel::Deprecation.output = previous_output
  end

  describe "#join_table" do
    it "renders ASOF LEFT JOIN with a condition and no deprecation" do
      sql = dataset.join_table(:asof_left, :b, { id: :id }).sql

      expect(sql).to include('FROM "a" ASOF LEFT JOIN "b" ON ("b"."id" = "a"."id")')
      expect(deprecations.string).to be_empty
    end

    {
      array: "ARRAY JOIN",
      left_array: "LEFT ARRAY JOIN",
      global_left: "GLOBAL LEFT JOIN",
      global_any_inner: "GLOBAL ANY INNER JOIN",
      left: "LEFT JOIN",
      left_outer: "LEFT OUTER JOIN",
      inner: "INNER JOIN",
    }.each do |type, join_sql|
      it "renders #{join_sql} without deprecations" do
        expect(dataset.join_table(type, :b).sql).to include(%(FROM "a" #{join_sql} "b"))
        expect(deprecations.string).to be_empty
      end
    end

    it "preserves Sequel's fallback SQL for an unknown join type" do
      expect(dataset.join_table(:bogus, :b).sql).to include('FROM "a" BOGUS JOIN "b"')
    end

    it "preserves Sequel's deprecation for an unknown join type" do
      dataset.join_table(:bogus, :b).sql

      expect(deprecations.string).to include("Unrecognized join type used: :bogus.")
    end
  end
end
