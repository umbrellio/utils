# frozen_string_literal: true

module UmbrellioUtils
  module Control
    extend self

    class UniqueConstraintViolation < StandardError; end

    def run_in_interval(interval, key:)
      previous_string = Store[key]
      previous = previous_string ? Time.zone.parse(previous_string) : Time.utc(0)

      return if previous + interval > Time.current
      Store[key] = Time.current

      yield
    ensure
      Store.delete(key) rescue nil
    end

    def retry_on_unique_violation(times: Float::INFINITY, checked_constraints: [], &block)
      retry_on(Sequel::UniqueConstraintViolation, times: times) do
        DB.transaction(savepoint: true, &block)
      rescue Sequel::UniqueConstraintViolation => error
        constraint_name = Database.get_violated_constraint_name(error)

        if checked_constraints.include?(constraint_name)
          raise error
        else
          raise UniqueConstraintViolation, error.message
        end
      end
    end

    def run_non_critical(rescue_all: false)
      yield
    rescue (rescue_all ? Exception : StandardError) => error
      Exceptions.notify!(error)
      nil
    end

    def retry_on(exception, times: Float::INFINITY, wait: 0)
      retries = 0

      begin
        yield
      rescue exception
        retries += 1
        raise if retries > times
        sleep(wait)
        retry
      end
    end
  end
end
