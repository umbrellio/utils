# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module UmbrellioUtils
  module Database
    extend self

    HandledConstaintError = Class.new(StandardError)
    InvalidPkError = Class.new(StandardError)

    def handle_constraint_error(constraint_name, &)
      DB.transaction(savepoint: true, &)
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

    def each_record(dataset, primary_key: nil, **options, &block)
      primary_key = primary_key_from(dataset, primary_key:)

      with_temp_table(dataset, primary_key:, **options) do |ids|
        rows = ids.map { |id| row(id.is_a?(Hash) ? id.values : [id]) }
        dataset.model.where(row(primary_key) => rows).reverse(row(primary_key)).each(&block)
      end
    end

    # Iterates over a dataset and yields batches of primary keys.
    # First, a temporary table is created and populated with dataset primary keys.
    # After that, a batch of rows is deleted from the temp table on each iteration
    # and gets yielded to the caller.
    # @option [Integer] page_size max size of each yielded PK batch
    # @option [Integer] sleep interval to sleep between each iteration
    # @option [Array] primary_key custom primary key to use for dataset
    # @option [Symbol, String] temp_table_name custom name for temporary table,
    #   table is reused if already exists
    # rubocop:disable Metrics/ParameterLists
    def with_temp_table(
      dataset,
      page_size: 1_000,
      sleep: nil,
      primary_key: nil,
      temp_table_name: nil,
      transaction: true
    )
      primary_key = primary_key_from(dataset, primary_key:)
      sleep_interval = sleep_interval_from(sleep)

      temp_table_name = create_temp_table(
        dataset, primary_key:, temp_table_name: temp_table_name&.to_sym
      )

      pk_set = []

      loop do
        conditional_transaction(transaction) do
          pk_set = pop_next_pk_batch(temp_table_name, primary_key, page_size)
          yield(pk_set) if pk_set.any?
        end

        break if pk_set.empty?

        Kernel.sleep(sleep_interval) if sleep_interval.positive?
      end

      DB.drop_table(temp_table_name)
    end
    # rubocop:enable Metrics/ParameterLists

    def create_temp_table(dataset, primary_key: nil, temp_table_name: nil)
      time = Time.current
      model = dataset.model

      temp_table_name ||= :"temp_#{model.table_name}_#{time.to_i}_#{time.nsec}"
      return temp_table_name if DB.table_exists?(temp_table_name)

      primary_key = primary_key_from(dataset, primary_key:)

      DB.create_table(temp_table_name, unlogged: true) do
        primary_key.each do |field|
          type = model.db_schema[field][:db_type]
          column(field, type)
        end

        primary_key(primary_key)
      end

      insert_ds = dataset.select(*qualified_pk(model.table_name, primary_key))
      DB[temp_table_name].disable_insert_returning.insert(insert_ds)

      temp_table_name
    end

    private

    def conditional_transaction(transaction, &)
      if transaction
        DB.transaction(&)
      else
        yield
      end
    end

    def row(values)
      return values if values.size == 1
      Sequel.function(:row, *values)
    end

    def extract_primary_key(dataset)
      dataset.db.schema(dataset.first_source).select { |x| x[1][:primary_key] }.map(&:first)
    end

    def primary_key_from(dataset, **options)
      Array(options[:primary_key] || extract_primary_key(dataset)).tap do |primary_key|
        raise InvalidPkError if primary_key.empty?
      end
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
# rubocop:enable Metrics/ModuleLength
