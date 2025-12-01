# frozen_string_literal: true

module UmbrellioUtils
  module Migrations # rubocop:disable Metrics/ModuleLength
    extend self

    def create_new_id_bigint_column(table_name)
      DB.run(<<~SQL.squish)
        LOCK TABLE #{table_name} IN ACCESS EXCLUSIVE MODE;

        CREATE OR REPLACE FUNCTION id_trigger()
        RETURNS trigger
        AS
        $BODY$
        DECLARE
        BEGIN
            NEW.id_bigint := NEW.id;
            RETURN NEW;
        END;
        $BODY$ LANGUAGE plpgsql;

        ALTER TABLE #{table_name} ADD id_bigint BIGINT;

        CREATE TRIGGER #{table_name}_bigint
          BEFORE INSERT OR UPDATE
          ON #{table_name}
          FOR EACH ROW
          EXECUTE FUNCTION id_trigger();
      SQL
    end

    def drop_old_id_column(table_name, associations = {}, skip_fk_create: false) # rubocop:disable Metrics/MethodLength
      query_start = <<~SQL.squish
        LOCK TABLE #{table_name} IN ACCESS EXCLUSIVE MODE;
        DROP TRIGGER #{table_name}_bigint ON #{table_name};
        ALTER TABLE #{table_name} RENAME id TO id_integer;
        ALTER TABLE #{table_name} RENAME id_bigint TO id;

        CREATE SEQUENCE IF NOT EXISTS new_#{table_name}_id_seq
          START WITH 1
          INCREMENT BY 1
          NO MINVALUE
          NO MAXVALUE
          CACHE 1;

        SELECT setval(
          'new_#{table_name}_id_seq',
          COALESCE((SELECT MAX(id) + 1 FROM #{table_name}), 1),
          false
        );
        ALTER TABLE #{table_name}
          ALTER COLUMN id SET DEFAULT nextval('new_#{table_name}_id_seq');
      SQL

      fkey_query = ""
      associations.map do |assoc_table, assoc_name|
        constraint_name = "#{assoc_table}_#{assoc_name}_fkey"

        fkey_query += <<~SQL.squish
          ALTER TABLE #{assoc_table}
          DROP CONSTRAINT IF EXISTS #{constraint_name}
        SQL
        if skip_fk_create
          fkey_query += ";"
          next
        end

        fkey_query += <<~SQL.squish
          , ADD CONSTRAINT #{constraint_name}
          FOREIGN KEY (#{assoc_name}) REFERENCES #{table_name}(id) NOT VALID;
        SQL
      end

      query_end = <<~SQL.squish
        ALTER TABLE #{table_name} DROP id_integer;
        ALTER TABLE #{table_name} ADD CONSTRAINT #{table_name}_pkey PRIMARY KEY
          USING INDEX #{table_name}_id_bigint_index;
      SQL

      query = query_start + fkey_query + query_end
      DB.run(query)
    end

    def drop_foreign_keys(_table_name, associations)
      associations.map do |assoc_table, assoc_name|
        constraint_name = "#{assoc_table}_#{assoc_name}_fkey"
        fkey_query = <<~SQL.squish
          ALTER TABLE #{assoc_table} DROP CONSTRAINT IF EXISTS #{constraint_name};
        SQL
        DB.run(fkey_query)
      end
    end

    def create_foreign_keys(table_name, associations)
      associations.map do |assoc_table, assoc_name|
        constraint_name = "#{assoc_table}_#{assoc_name}_fkey"
        fkey_query = <<~SQL.squish
          DO $$
          BEGIN
            IF NOT EXISTS (
              SELECT 1
              FROM pg_constraint
              WHERE conname = '#{constraint_name}'
            ) THEN
              ALTER TABLE #{assoc_table} ADD CONSTRAINT #{constraint_name}
                FOREIGN KEY (#{assoc_name}) REFERENCES #{table_name}(id) NOT VALID;
            END IF;
          END$$;
        SQL
        DB.run(fkey_query)
      end
    end

    def create_new_foreign_key_column(table_name, column_name)
      DB.run(<<~SQL.squish)
        LOCK TABLE #{table_name} IN ACCESS EXCLUSIVE MODE;

        CREATE OR REPLACE FUNCTION #{column_name}_bigint_trigger()
        RETURNS trigger
        AS
        $BODY$
        DECLARE
        BEGIN
            NEW.#{column_name}_bigint := NEW.#{column_name};
            RETURN NEW;
        END;
        $BODY$ LANGUAGE plpgsql;

        ALTER TABLE #{table_name} ADD #{column_name}_bigint BIGINT;

        CREATE TRIGGER #{table_name}_#{column_name}_bigint
          BEFORE INSERT OR UPDATE
          ON #{table_name}
          FOR EACH ROW
          EXECUTE FUNCTION #{column_name}_bigint_trigger();
      SQL
    end

    def check_id_consistency(table_name, col_name = "id")
      res = DB[table_name].where(
        Sequel[col_name.to_sym] !~ SQL.coalesce(Sequel[:"#{col_name}_bigint"], 0),
      ).count
      raise "Inconsistent ids in #{table_name}: #{res} records" if res.positive?
      true
    end

    # rubocop:disable Metrics/MethodLength
    def drop_old_foreign_key_column(table_name, column_name, skip_constraint: false,
                                    primary_key: [], uniq_constr: false)
      query_start = <<~SQL.squish
        LOCK TABLE #{table_name} IN ACCESS EXCLUSIVE MODE;
        DROP TRIGGER #{table_name}_#{column_name}_bigint ON #{table_name};
        ALTER TABLE #{table_name} RENAME #{column_name} TO #{column_name}_integer;
        ALTER TABLE #{table_name} RENAME #{column_name}_bigint TO #{column_name};
      SQL

      fkey_query = ""
      unless skip_constraint
        constraint_name = "#{table_name}_#{column_name}_fkey"
        ref_table_name = column_name.to_s.delete_suffix("_id").pluralize
        fkey_query = <<~SQL.squish
          ALTER TABLE #{table_name}
          DROP CONSTRAINT IF EXISTS #{constraint_name},
          ADD CONSTRAINT #{constraint_name}
          FOREIGN KEY (#{column_name}) REFERENCES #{ref_table_name}(id) NOT VALID;
        SQL
      end

      drop_query = <<~SQL.squish
        ALTER TABLE #{table_name} DROP #{column_name}_integer;
      SQL

      constr_query = ""
      if uniq_constr
        constr_query = <<~SQL.squish
          ALTER TABLE #{table_name}
          ADD CONSTRAINT #{table_name}_#{column_name}_key UNIQUE (#{column_name});
        SQL
      end

      pkey_query = ""
      if primary_key.present?
        pkey_query = <<~SQL.squish
          ALTER TABLE #{table_name} ADD CONSTRAINT #{table_name}_pkey PRIMARY KEY
            USING INDEX #{table_name}_#{primary_key.join("_")}_index;
        SQL
      end

      query = query_start + fkey_query + drop_query + constr_query + pkey_query
      DB.run(query)
    end
    # rubocop:enable Metrics/MethodLength

    def check_associations(model, method, reverse_method)
      model.dataset.limit(10).all.each do |record|
        res = record.public_send(method).public_send(reverse_method)
        raise StandardError if res.blank?
      end
      true
    end

    def create_distributed_table!(table_name, sharding_key, db_name: UmbrellioUtils::ClickHouse.db_name)
      UmbrellioUtils::ClickHouse.execute(<<~SQL.squish)
        DROP TABLE IF EXISTS #{db_name}.#{table_name}_distributed
        ON CLUSTER click_cluster
      SQL

      UmbrellioUtils::ClickHouse.execute(<<~SQL.squish)
        CREATE TABLE #{db_name}.#{table_name}_distributed
        ON CLUSTER click_cluster
        AS #{db_name}.#{table_name}
        ENGINE = Distributed(click_cluster, #{db_name}, #{table_name}, #{sharding_key})
      SQL
    end

    # @example
    # add_columns_to_view(
    #   "orders_clickhouse_view",
    #   Sequel[:orders][:data].pg_jsonb.get_text("some_data_column").as(:some_column),
    #   Sequel[:orders][:column].as(:some_other_column),
    # )
    def add_columns_to_view(view_name, *sequel_columns)
      sequel_columns.each do |column|
        unless column.is_a?(Sequel::SQL::AliasedExpression)
          raise ArgumentError.new("not Sequel::SQL::AliasedExpression")
        end
      end

      DB.transaction do
        DB.run("LOCK TABLE #{view_name}")
        definition = view_definition(view_name)
        sql = sequel_columns.map { |x| DB.literal(x) }.join(", ")
        new_definition = definition.sub("FROM", ", #{sql} FROM")
        DB.run("CREATE OR REPLACE VIEW #{view_name} AS #{new_definition}")
      end
    end

    # @example
    # drop_columns_from_view("orders_clickhouse_view", "id", "guid")
    def drop_columns_from_view(view_name, *columns)
      DB.transaction do
        DB.run("LOCK TABLE #{view_name}")
        definition = view_definition(view_name)
        parsed_columns = parse_columns(definition)
        parsed_columns.reject! { |name, _| name.in?(columns) }
        sql = parsed_columns.map { |_, sql| sql }.join(", ")
        new_definition = definition.sub(/SELECT(.*?)FROM/i, "SELECT #{sql} FROM")
        DB.run("DROP VIEW #{view_name}")
        DB.run("CREATE VIEW #{view_name} AS #{new_definition}")
      end
    end

    private

    def parse_columns(definition)
      fields_sql = definition[/SELECT(.*?)FROM/i, 1].strip
      fields = fields_sql.scan(/(?:[^,(]+|\([^)]*\))+/).map(&:strip)
      field_names = fields.map do |field|
        field[/as (.*)/i, 1] || field[/\.(.*)\z/, 1]
      end
      field_names.zip(fields)
    end

    def view_definition(view)
      DB[:pg_views]
        .where(viewname: view.to_s)
        .select(:definition).first[:definition]
        .squish
    end
  end
end
