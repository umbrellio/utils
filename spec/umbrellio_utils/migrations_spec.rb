# frozen_string_literal: true

describe UmbrellioUtils::Migrations do
  before do
    DB.drop_table? :test_migrations, cascade: true
    DB.create_table :test_migrations do
      primary_key :id
      column :test, :text
    end

    DB.run("CREATE OR REPLACE VIEW test_migrations_view AS SELECT id from users")

    DB.drop_table? :test_migration_references
    DB.create_table :test_migration_references do
      primary_key :id
      foreign_key :test_migration_id, :test_migrations
    end
  end

  before do
    DB[:test_migrations].multi_insert(test_data)
    DB[:test_migration_references].multi_insert(test_reference_data)
  end

  let(:test_data) do
    Array.new(10) { |index| Hash[id: index + 1, test: index.to_s] }
  end

  let(:test_reference_data) do
    Array.new(10) { |index| Hash[id: index + 1, test_migration_id: index + 1] }
  end

  context "with migrate to bigint" do
    def expected_foreign_key
      DB.foreign_key_list(:test_migration_references).first
    end

    def check_contains_fk!
      expect(expected_foreign_key).to include(
        columns: [:test_migration_id], table: :test_migrations,
      )
    end

    def check_contains_no_fk!
      expect(expected_foreign_key).to be_nil
    end

    let(:associations) { Hash[test_migration_references: :test_migration_id] }

    it "migrates to bigint column" do
      described_class.create_new_id_bigint_column(:test_migrations)
      expect(DB[:test_migrations].columns).to eq(%i[id test id_bigint]) # creates id_bigint column

      # contains trigger which copy from id column
      DB[:test_migrations].insert(id: 11, test: 11)
      expect(DB[:test_migrations].first(id: 11)).to eq(id: 11, test: "11", id_bigint: 11)

      DB[:test_migrations].update(id_bigint: :id)
      DB.alter_table(:test_migrations) { add_index :id_bigint, unique: true }
      described_class.check_id_consistency(:test_migrations)

      described_class.drop_old_id_column(:test_migrations, associations)
      DB[:test_migrations].send(:clear_columns_cache)
      expect(DB[:test_migrations].columns).to eq(%i[test id])
      expect(DB.schema(:test_migrations).to_h[:id]).to include(db_type: "bigint", primary_key: true)
      check_contains_fk!
    end

    it "updates foreign key to bigint" do
      described_class.create_new_foreign_key_column(:test_migration_references, :test_migration_id)
      expect(DB[:test_migration_references].columns).to eq( # creates bigint column
        %i[id test_migration_id test_migration_id_bigint],
      )

      # contains trigger which copy from test_migration_id column
      DB[:test_migrations].insert(id: 11, test: 11)
      DB[:test_migration_references].insert(id: 11, test_migration_id: 11)
      expect(DB[:test_migration_references].first(id: 11)).to eq(
        id: 11, test_migration_id: 11, test_migration_id_bigint: 11,
      )

      DB[:test_migration_references].update(test_migration_id: :id)

      described_class.drop_old_foreign_key_column(:test_migration_references, :test_migration_id)
      DB[:test_migration_references].send(:clear_columns_cache)
      expect(DB[:test_migration_references].columns).to eq(%i[id test_migration_id])
      expect(DB[:test_migration_references].first(id: 11)).to eq(id: 11, test_migration_id: 11)
      type = DB.schema(:test_migration_references).to_h.dig(:test_migration_id, :db_type)
      expect(type).to eq("bigint")
      check_contains_fk!
    end

    context "with skip create fk" do
      it "doesn't create fk" do
        described_class.create_new_id_bigint_column(:test_migrations)
        DB[:test_migrations].update(id_bigint: :id)
        DB.alter_table(:test_migrations) { add_index :id_bigint, unique: true }
        described_class.drop_old_id_column(:test_migrations, associations, skip_fk_create: true)

        check_contains_no_fk!
      end
    end

    context "with drop and create foreign keys" do
      specify do
        described_class.drop_foreign_keys(:test_migration_references, associations)
        check_contains_no_fk!
        described_class.create_foreign_keys(:test_migrations, associations)
        check_contains_fk!
      end
    end
  end

  describe "#check_id_consistency" do
    specify do
      described_class.create_new_id_bigint_column(:test_migrations)
      expect { described_class.check_id_consistency(:test_migrations) }.to raise_error(
        RuntimeError, /Inconsistent ids in test_migrations: 10 records/
      )
    end
  end

  describe "#check_associations" do
    specify do
      result = described_class.check_associations(
        TestMigrationReference, :test_migration, :test_migration_references
      )
      expect(result).to be_truthy
    end

    context "with invalid" do
      it "raises error" do
        stub_const("TestMigrationReference", Class.new(Sequel::Model(:test_migrations)) do
          def test_migration
            Struct.new(:test_migration_references).new(test_migration_references: [])
          end
        end)

        expect do
          described_class.check_associations(
            TestMigrationReference, :test_migration, :test_migration_references
          )
        end.to raise_error(StandardError)
      end
    end
  end

  describe "#create_distributed_table" do
    specify do
      described_class.create_distributed_table!("test", "id")
      expect(UmbrellioUtils::ClickHouse.describe_table("test_distributed")).to be_present
    end
  end

  context "with view" do
    specify do
      described_class.add_columns_to_view("test_migrations_view", Sequel[:email].as(:test))
      expect(DB[:test_migrations_view].columns).to eq(%i[id test])

      described_class.drop_columns_from_view("test_migrations_view", "test")
      DB[:test_migrations_view].send(:clear_columns_cache)
      expect(DB[:test_migrations_view].columns).to eq(%i[id])
    end
  end
end
