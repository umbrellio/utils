# frozen_string_literal: true

describe UmbrellioUtils::SQL do
  let(:sql) { described_class }

  subject(:result) { DB.literal(expr) }

  describe "#[]" do
    let(:expr) { sql[:test] }

    specify { expect(result).to eq('"test"') }
  end

  describe "#func" do
    let(:expr) { sql.func(:some_function, :test) }

    specify { expect(result).to eq('some_function("test")') }
  end

  describe "#cast" do
    let(:expr) { sql.cast(:test, :integer) }

    specify { expect(result).to eq('CAST("test" AS integer)') }
  end

  describe "#case" do
    let(:expr) { sql.case({ sql[:test] =~ sql[:test2] => 1 }, 2) }

    specify { expect(result).to eq('(CASE WHEN ("test" = "test2") THEN 1 ELSE 2 END)') }
  end

  describe "#pg_jsonb" do
    let(:expr) { sql.pg_jsonb(test: 123) }

    specify { expect(result).to eq(%('{"test":123}'::jsonb)) }
  end

  describe "#and" do
    let(:expr) { sql.and({ test: 123 }, { test2: 321 }) }

    specify { expect(result).to eq('(("test" = 123) AND ("test2" = 321))') }
  end

  describe "#or" do
    let(:expr) { sql.or({ test: 123 }, { test2: 321 }) }

    specify { expect(result).to eq('(("test" = 123) OR ("test2" = 321))') }
  end

  describe "#to_utc" do
    let(:expr) { sql.to_utc("2020-01-01 00:00:00.000000") }

    specify { expect(result).to eq("timezone('UTC', '2020-01-01 00:00:00.000000')") }
  end

  describe "#to_timezone" do
    let(:expr) { sql.to_timezone("UTC+6", "2020-01-01 00:00:00.000000") }

    specify do
      expect(result).to eq(
        "timezone('UTC+6', CAST(timezone('UTC', '2020-01-01 00:00:00.000000') AS timestamptz))",
      )
    end
  end

  describe "#pg_range" do
    let(:expr) { sql.pg_range(Time.zone.parse("2014-01-01"), Time.zone.parse("2015-01-01")) }

    specify do
      expect(result).to eq("'[2014-01-01 00:00:00.000000+0000,2015-01-01 00:00:00.000000+0000]'")
    end
  end

  describe "#pg_range_by_range" do
    let(:expr) do
      sql.pg_range_by_range(Time.zone.parse("2014-01-01")..Time.zone.parse("2015-01-01"))
    end

    specify do
      expect(result).to eq("'[2014-01-01 00:00:00.000000+0000,2015-01-01 00:00:00.000000+0000]'")
    end
  end

  describe "#coalesce0" do
    let(:expr) { sql.coalesce0("test") }

    specify { expect(result).to eq("coalesce('test', 0)") }
  end

  describe "#nullif" do
    let(:expr) { sql.nullif(1, 1) }

    specify { expect(result).to eq("nullif(1, 1)") }
  end

  %w[max min sum avg abs coalesce least greatest distinct jsonb_typeof row].each do |function|
    describe "##{function}" do
      let(:expr) { sql.public_send(function, :test) }

      specify { expect(result).to eq(%(#{function}("test"))) }
    end
  end

  describe "#count" do
    context "with expression" do
      let(:expr) { sql.count(:test) }

      specify { expect(result).to eq('count("test")') }
    end

    context "without expression" do
      let(:expr) { sql.count }

      specify { expect(result).to eq("count(*)") }
    end
  end

  describe "#ch_count" do
    let(:expr) { sql.ch_count(:test) }

    specify { expect(result).to eq('count("test")') }
  end

  describe "#pg_percentile" do
    let(:expr) { sql.pg_percentile(:test, 0.1) }

    specify { expect(result).to eq('percentile_cont(0.1) WITHIN GROUP (ORDER BY "test")') }
  end

  describe "#pg_median" do
    let(:expr) { sql.pg_median(:test) }

    specify { expect(result).to eq('percentile_cont(0.5) WITHIN GROUP (ORDER BY "test")') }
  end

  describe "#ch_median" do
    let(:expr) { sql.ch_median(:test) }

    specify { expect(result).to eq('median("test")') }
  end

  describe "#date_trunc" do
    let(:expr) { sql.date_trunc("hour", :test) }

    specify { expect(result).to eq(%(date_trunc('hour', "test"))) }
  end

  describe "#ch_timestamp" do
    context "with time" do
      let(:expr) { sql.ch_timestamp(Time.zone.parse("2020-01-01")) }

      specify { expect(result).to eq("'2020-01-01 00:00:00.000000'") }
    end

    context "with nil" do
      let(:expr) { sql.ch_timestamp(nil) }

      specify { expect(result).to eq("NULL") }
    end
  end

  describe "#ch_timestamp_expr" do
    context "with time" do
      let(:expr) { sql.ch_timestamp_expr(Time.zone.parse("2020-01-01")) }

      specify { expect(result).to eq("toDateTime64('2020-01-01 00:00:00.000000', 6)") }
    end

    context "with string" do
      let(:expr) { sql.ch_timestamp_expr("2020-01-01") }

      specify { expect(result).to eq("toDateTime64('2020-01-01 00:00:00.000000', 6)") }
    end
  end

  describe "#ch_time_range" do
    let(:expr) { sql.ch_time_range(Time.zone.parse("2020-01-01")..Time.zone.parse("2020-01-02")) }

    specify { expect(result).to eq("'[2020-01-01 00:00:00.000000,2020-01-02 00:00:00.000000]'") }
  end

  describe "#jsonb_dig" do
    let(:expr) { sql.jsonb_dig(sql[:test].pg_jsonb, %w[test test2]) }

    specify { expect(result).to eq(%("test"['test']['test2'])) }
  end

  describe "#empty_jsonb" do
    let(:expr) { sql.empty_jsonb }

    specify { expect(result).to eq("'{}'::jsonb") }
  end

  describe "#round" do
    let(:expr) { sql.round(:test, 5) }

    specify { expect(result).to eq('round("test", 5)') }
  end

  describe "#map_to_expr" do
    let(:expr) { sql.map_to_expr({ test: Sequel[:test1], test2: Sequel[:some] }) }

    specify { expect(result).to eq('("test1" AS "test", "some" AS "test2")') }
  end

  describe "#intersect" do
    let(:expr) { sql.intersect(:test, :test2) }

    specify { expect(result).to eq('SELECT "test" INTERSECT SELECT "test2"') }
  end

  describe "#jsonb_unsafe_set" do
    let(:expr) { sql.jsonb_unsafe_set(sql[:test].pg_jsonb, %w[test test2], 123) }

    specify do
      expect(result).to eq(
        <<~SQL.squish.gsub("( ", "(").gsub(" )", ")"),
          jsonb_set(
            "test", ('test'),
            (CASE WHEN (123 IS NULL) THEN (
                CASE WHEN (
                  jsonb_typeof("test"['test']) IN ('object', 'array')
                ) THEN "test"['test'] ELSE '{}'::jsonb END
              ) ELSE jsonb_set(
                (CASE WHEN (
                    jsonb_typeof("test"['test']) IN ('object', 'array')
                  ) THEN "test"['test'] ELSE '{}'::jsonb END),
                ('test2'),
                123,
                true
              ) END
            ),
            true)
        SQL
      )
    end
  end

  describe "#true" do
    let(:expr) { sql.true }

    specify { expect(result).to eq("true") }
  end

  describe "#false" do
    let(:expr) { sql.false }

    specify { expect(result).to eq("false") }
  end
end
