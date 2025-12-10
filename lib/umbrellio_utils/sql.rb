# frozen_string_literal: true

module UmbrellioUtils
  module SQL
    extend self

    UniqueConstraintViolation = Sequel::UniqueConstraintViolation

    def [](*args)
      Sequel[*args]
    end

    def func(...)
      Sequel.function(...)
    end

    def cast(...)
      Sequel.cast(...)
    end

    def case(...)
      Sequel.case(...)
    end

    def pg_jsonb(...)
      Sequel.pg_jsonb(...)
    end

    def to_utc(date)
      func(:timezone, "UTC", date)
    end

    def to_timezone(zone, date)
      utc_date = to_utc(date)
      func(:timezone, zone, cast(utc_date, :timestamptz))
    end

    def and(*conditions)
      Sequel.&(*Array(conditions.flatten.presence || true))
    end

    def not(...)
      Sequel.~(...)
    end

    def or(*conditions)
      Sequel.|(*Array(conditions.flatten.presence || true))
    end

    def pg_range(from_value, to_value, **opts)
      Sequel::Postgres::PGRange.new(from_value, to_value, **opts)
    end

    def pg_range_by_range(range)
      Sequel::Postgres::PGRange.from_range(range)
    end

    def max(expr)
      func(:max, expr)
    end

    def min(expr)
      func(:min, expr)
    end

    def sum(expr)
      func(:sum, expr)
    end

    def count(expr = nil)
      expr ? func(:count, expr) : func(:count).*
    end

    def ch_count(*args)
      Sequel.function(:count, *args)
    end

    def avg(expr)
      func(:avg, expr)
    end

    def pg_percentile(expr, percentile)
      func(:percentile_cont, percentile).within_group(expr)
    end

    def pg_median(expr)
      pg_percentile(expr, 0.5)
    end

    def ch_median(expr)
      func(:median, expr)
    end

    def abs(expr)
      func(:abs, expr)
    end

    def coalesce(*exprs)
      func(:coalesce, *exprs)
    end

    def coalesce0(*args)
      coalesce(*args, 0)
    end

    def nullif(main_expr, checking_expr)
      func(:nullif, main_expr, checking_expr)
    end

    def distinct(expr)
      func(:distinct, expr)
    end

    def least(*exprs)
      func(:least, *exprs)
    end

    def greatest(*exprs)
      func(:greatest, *exprs)
    end

    def date_trunc(truncate, expr)
      func(:date_trunc, truncate.to_s, expr)
    end

    def ch_timestamp(time)
      time&.strftime("%F %T.%6N")
    end

    def ch_timestamp_expr(time)
      time = Time.zone.parse(time) if time.is_a?(String)
      func(:toDateTime64, Sequel[ch_timestamp(time)], 6)
    end

    def ch_time_range(range)
      Range.new(ch_timestamp(range.begin), ch_timestamp(range.end), range.exclude_end?)
    end

    def jsonb_dig(jsonb, path)
      path.reduce(jsonb) { |acc, cur| acc[cur] }
    end

    def jsonb_typeof(jsonb)
      func(:jsonb_typeof, jsonb)
    end

    def empty_jsonb
      Sequel.pg_jsonb({})
    end

    def round(value, precision = 0)
      func(:round, value, precision)
    end

    def row(*values)
      func(:row, *values)
    end

    def map_to_expr(hash)
      hash.map { |aliaz, expr| expr.as(aliaz) }
    end

    def intersect(left_expr, right_expr)
      Sequel.lit("SELECT ? INTERSECT SELECT ?", left_expr, right_expr)
    end

    # can rewrite scalar values
    def jsonb_unsafe_set(jsonb, path, value)
      parent_path = path.slice(..-2)
      raw_parent = jsonb_dig(jsonb, parent_path)
      parent = jsonb_rewrite_scalar(raw_parent)
      last_path = path.slice(-1..-1)
      updated_parent = parent.set(last_path, value)
      result = self.case({ { value => nil } => parent }, updated_parent)
      jsonb.set(parent_path, result)
    end

    def true
      Sequel.lit("true")
    end

    def false
      Sequel.lit("false")
    end

    private

    def jsonb_rewrite_scalar(jsonb)
      self.case({ { jsonb_typeof(jsonb) => %w[object array] } => jsonb }, empty_jsonb).pg_jsonb
    end
  end
end
