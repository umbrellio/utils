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

    def and(*conditions)
      Sequel.&(*Array(conditions.flatten.presence || true))
    end

    def not(...)
      Sequel.~(...)
    end

    def or(*conditions)
      Sequel.|(*Array(conditions.flatten.presence || true))
    end

    def range(from_value, to_value, **opts)
      Sequel::Postgres::PGRange.new(from_value, to_value, **opts)
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
      SQL.func(:toDateTime64, SQL[ch_timestamp(time)], 6)
    end

    def true
      Sequel.lit("true")
    end

    def false
      Sequel.lit("false")
    end
  end
end
