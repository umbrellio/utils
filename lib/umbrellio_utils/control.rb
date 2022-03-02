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

    def retry_on_unique_violation(
      times: Float::INFINITY, retry_on_all_constraints: false, checked_constraints: [], &block
    )
      use_savepoint = retry_on_all_constraints || checked_constraints.present?
      retry_on(Sequel::UniqueConstraintViolation, times: times) do
        DB.transaction(savepoint: use_savepoint, &block)
      rescue Sequel::UniqueConstraintViolation => e
        constraint_name = Database.get_violated_constraint_name(e)

        if retry_on_all_constraints || checked_constraints.include?(constraint_name)
          raise e
        else
          raise UniqueConstraintViolation, e.message
        end
      end
    rescue Sequel::UniqueConstraintViolation => e
      raise UniqueConstraintViolation, e.message
    end

    def run_non_critical(rescue_all: false, in_transaction: false, &block)
      in_transaction ? DB.transaction(savepoint: true, &block) : yield
    rescue (rescue_all ? Exception : StandardError) => e
      Exceptions.notify!(e)
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
