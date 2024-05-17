# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
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
      primary_key = primary_key_from(**options)

      with_temp_table(dataset, **options) do |ids|
        if primary_key.is_a?(Array)
          where_expr = Sequel.|(*ids.map { |id| complex_key_expr(primary_key, id) })
          dataset.model.where(where_expr).each(&block)
        else
          dataset.model.where(primary_key => ids).reverse(primary_key).each(&block)
        end
      end
    end

    def with_temp_table(dataset, page_size: 1_000, sleep: nil, **options)
      primary_key = primary_key_from(**options)
      sleep_interval = sleep_interval_from(sleep)

      temp_table_name = create_temp_table(dataset, primary_key: primary_key)

      pk_set = []

      loop do
        DB.transaction do
          pk_set = pop_pk_batch(primary_key, temp_table_name, page_size)
          yield(pk_set) if pk_set.any?
        end

        break if pk_set.empty?

        Kernel.sleep(sleep_interval) if sleep_interval.positive?
        clear_lamian_logs!
      end
    ensure
      DB.drop_table(temp_table_name)
    end

    def clear_lamian_logs!
      return unless defined?(Lamian)
      Lamian.logger.send(:logdevs).each { |x| x.truncate(0) && x.rewind }
    end

    def create_temp_table(dataset, primary_key:)
      time = Time.current
      temp_table_name = "temp_#{dataset.model.table_name}_#{time.to_i}_#{time.nsec}".to_sym

      DB.drop_table?(temp_table_name)
      if primary_key.is_a?(Array)
        create_complex_key_temp_table(temp_table_name, dataset, primary_key)
      else
        create_simple_key_temp_table(temp_table_name, dataset, primary_key)
      end

      temp_table_name
    end

    private

    def create_simple_key_temp_table(temp_table_name, dataset, primary_key)
      model = dataset.model
      type = model.db_schema[primary_key][:db_type]

      DB.create_table(temp_table_name, unlogged: true) do
        column primary_key, type, primary_key: true
      end

      insert_ds = dataset.select(Sequel[model.table_name][primary_key])
      DB[temp_table_name].disable_insert_returning.insert(insert_ds)
    end

    def create_complex_key_temp_table(temp_table_name, dataset, primary_key)
      model = dataset.model

      DB.create_table(temp_table_name, unlogged: true) do
        primary_key(:temp_table_id)

        primary_key.each do |field|
          type = model.db_schema[field][:db_type]
          column field, type
        end
      end

      insert_ds = dataset.select(
        Sequel.function(:row_number).over, *primary_key.map { |f| Sequel[model.table_name][f] }
      )
      DB[temp_table_name].disable_insert_returning.insert(insert_ds)
    end

    def pop_pk_batch(primary_key, temp_table_name, batch_size)
      pk_column = primary_key.is_a?(Array) ? :temp_table_id : primary_key
      pk_expr = DB[temp_table_name].select(pk_column).reverse(pk_column).limit(batch_size)
      deleted_items = DB[temp_table_name].where(pk_column => pk_expr).returning.delete
      deleted_items.map do |item|
        next complex_key_expr(primary_key, item) if primary_key.is_a?(Array)
        item[primary_key]
      end
    end

    def primary_key_from(**options)
      options.fetch(:primary_key, :id)
    end

    def sleep_interval_from(sleep)
      case sleep
      when Numeric
        sleep
      when FalseClass
        0
      else
        defined?(Rails) && Rails.env.production? ? 1 : 0
      end
    end

    def complex_key_expr(primary_key, record)
      primary_key.to_h { |field| [field, record[field]] }
    end
  end
end
# rubocop:enable Metrics/ModuleLength
