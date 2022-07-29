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
        dataset.model.where(primary_key => ids).each(&block)
      end
    end

    def with_temp_table(dataset, **options)
      primary_key = primary_key_from(**options)
      page_size = options.fetch(:page_size, 1_000)
      do_sleep = options.fetch(:sleep, Rails.env.production?)

      temp_table_name = create_temp_table(dataset, primary_key: primary_key)

      pk_set = []

      loop do
        DB.transaction do
          pk_expr = DB[temp_table_name].select(primary_key).reverse(primary_key).limit(page_size)

          deleted_items = DB[temp_table_name].where(primary_key => pk_expr).returning.delete
          pk_set = deleted_items.map { |item| item[primary_key] }

          yield(pk_set) if pk_set.any?
        end

        break if pk_set.empty?

        sleep(1) if do_sleep
        clear_lamian_logs!
      end
    ensure
      DB.drop_table(temp_table_name)
    end

    def clear_lamian_logs!
      Lamian.logger.send(:logdevs).each { |x| x.truncate(0) && x.rewind }
    end

    def create_temp_table(dataset, primary_key:)
      model = dataset.model
      time = Time.current
      temp_table_name = "temp_#{model.table_name}_#{time.to_i}#{time.nsec}".to_sym
      type = model.db_schema[primary_key][:db_type]

      DB.drop_table?(temp_table_name)
      DB.create_table(temp_table_name, unlogged: true) do
        column primary_key, type, primary_key: true
      end

      insert_ds = dataset.select(Sequel[model.table_name][primary_key])
      DB[temp_table_name].insert(insert_ds)
      temp_table_name
    end

    private

    def primary_key_from(**options)
      options.fetch(:primary_key, :id)
    end
  end
end
