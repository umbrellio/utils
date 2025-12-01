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

  describe "#range" do
    let(:expr) { sql.range(Time.zone.parse("2014-01-01"), Time.zone.parse("2015-01-01")) }

    specify do
      expect(result).to eq("'[2014-01-01 00:00:00.000000+0000,2015-01-01 00:00:00.000000+0000]'")
    end
  end

  %w[max min sum avg abs coalesce least greatest].each do |function|
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

  describe "#true" do
    let(:expr) { sql.true }

    specify { expect(result).to eq("true") }
  end

  describe "#false" do
    let(:expr) { sql.false }

    specify { expect(result).to eq("false") }
  end
end
