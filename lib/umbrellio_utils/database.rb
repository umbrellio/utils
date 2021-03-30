# frozen_string_literal: true

module UmbrellioUtils
  module Database
    extend self

    HandledConstaintError = Class.new(StandardError)

    def handle_constraint_error(constraint_name, &block)
      DB.transaction(savepoint: true, &block)
    rescue Sequel::UniqueConstraintViolation => e
      if constraint_name.to_s == get_violated_constraint_name(e)
        raise HandledConstaintError
      else
        raise e
      end
    end

    def get_violated_constraint_name(exception)
      error = exception.wrapped_exception
      error.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    end

    def each_record(dataset, **options, &block)
      primary_key = primary_key_from(options)
      with_temp_table(dataset, **options) do |ids|
        dataset.model.where(primary_key => ids).each(&block)
      end
    end

    def with_temp_table(dataset, **options)
      model = dataset.model
      temp_table_name = "temp_#{model.table_name}_#{Time.current.to_i}".to_sym

      DB.default.drop_table?(temp_table_name)
      DB.default.create_table(temp_table_name) { primary_key :id }

      temp_table = DB.default[temp_table_name]
      pk = primary_key_from(options)
      ids = nil
      temp_table.insert(dataset.select(pk))

      loop do
        DB.transaction do
          id_expr = temp_table.select(:id).reverse(:id).limit(1000)
          ids = temp_table.where(id: id_expr).returning.delete.map { |item| item[:id] }
          yield(ids) if ids.any?
        end

        break if ids.empty?
        sleep(1) if Rails.env.production?
        clear_lamian_logs!
      end
    ensure
      DB.default.drop_table(temp_table_name)
    end

    def clear_lamian_logs!
      Lamian.logger.send(:logdevs).each { |x| x.truncate(0) && x.rewind }
    end

    private

    def primary_key_from(options)
      options.fetch(:primary_key, :id)
    end
  end
end
