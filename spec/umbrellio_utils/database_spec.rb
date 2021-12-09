# frozen_string_literal: true

describe UmbrellioUtils::Database do
  describe "#create_temp_table" do
    let(:column_schema) { double("column_schema") }
    let(:schema) { double("schema") }
    let(:model) { double("model", table_name: "test_table_name", db_schema: schema) }
    let(:dataset) { double("dataset", model: model) }
    let(:sequel) { double("sequel") }
    let(:table) { double("table") }
    let(:select_expr) { double("select_expression") }

    # rubocop:disable Naming/VariableNumber
    let(:table_name) { :temp_test_table_name_16387488000 }
    # rubocop:enable Naming/VariableNumber

    before { Timecop.freeze("2021-12-06 UTC") }

    before do
      stub_const("DB", double)
      stub_const("Sequel", sequel)
    end

    before do
      allow(schema).to receive(:[]).with("test_primary_key").and_return(column_schema)
      allow(column_schema).to receive(:[]).with(:db_type).and_return("test_type")

      allow(DB).to receive(:drop_table?)
      allow(DB).to receive(:create_table).with(table_name, unlogged: true)
      allow(DB).to receive(:[]).with(table_name).and_return(table)

      allow(Sequel).to receive(:[]).with("test_table_name").and_return(table)

      allow(table).to receive(:[]).with("test_primary_key").and_return(select_expr)
      allow(dataset).to receive(:select).with(select_expr).and_return(dataset)
      allow(table).to receive(:insert).with(dataset)
    end

    subject(:result) do
      described_class.create_temp_table(dataset, primary_key: "test_primary_key")
    end

    specify do
      expect(result).to eq(table_name)
    end
  end
end
