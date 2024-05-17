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
      primary_key = primary_key_from(**options)

      with_temp_table(dataset, **options) do |ids|
        rows = ids.map { |id| row(id.is_a?(Hash) ? id.values : [id]) }
        dataset.model.where(row(primary_key) => rows).reverse(row(primary_key)).each(&block)
      end
    end

    def with_temp_table(dataset, page_size: 1_000, sleep: nil, **options)
      primary_key = primary_key_from(**options)
      sleep_interval = sleep_interval_from(sleep)

      temp_table_name = create_temp_table(dataset, primary_key: primary_key)

      pk_set = []

      loop do
        DB.transaction do
          pk_set = pop_next_pk_batch(temp_table_name, primary_key, page_size)
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

    def create_temp_table(dataset, **options)
      time = Time.current
      model = dataset.model
      temp_table_name = "temp_#{model.table_name}_#{time.to_i}_#{time.nsec}".to_sym
      primary_key = primary_key_from(**options)

      DB.create_table(temp_table_name, unlogged: true) do
        primary_key.each do |field|
          type = model.db_schema[field][:db_type]
          column field, type
        end

        primary_key primary_key
      end

      insert_ds = dataset.select(*qualified_pk(model.table_name, primary_key))
      DB[temp_table_name].disable_insert_returning.insert(insert_ds)

      temp_table_name
    end

    private

    def row(values)
      Sequel.function(:row, *values)
    end

    def primary_key_from(**options)
      Array(options.fetch(:primary_key, :id))
    end

    def qualified_pk(table_name, primary_key)
      primary_key.map { |f| Sequel[table_name][f] }
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

    def pop_next_pk_batch(temp_table_name, primary_key, batch_size)
      row = row(primary_key)
      pk_expr = DB[temp_table_name].select(*primary_key).reverse(row).limit(batch_size)
      deleted_items = DB[temp_table_name].where(row => pk_expr).returning.delete
      deleted_items.map do |item|
        next item if primary_key.size > 1
        item[primary_key.first]
      end
    end
  end
end
