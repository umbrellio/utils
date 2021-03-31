# frozen_string_literal: true

describe UmbrellioUtils do
  it "has a version number" do
    expect(described_class::VERSION).not_to be nil
  end

  it "sets proper default configuration" do
    expect(described_class.config.to_h).to eq(
      store_table_name: :store,
      http_client_name: :application_httpclient,
    )
  end

  context "with config changing" do
    around do |example|
      old_config = described_class.instance_variable_get(:@config).dup
      described_class.configure { |config| config.store_table_name = :brand_new_name }
      example.call
      described_class.instance_variable_set(:@config, old_config)
    end

    it "properly changes settings" do
      described_class.config.store_table_name = :brand_new_name
    end
  end

  context "with module extending" do
    let(:utils_module) do
      included_module = described_class

      Module.new do
        extend included_module
      end
    end

    it "references to same config" do
      expect(utils_module.config.object_id).to eq(described_class.config.object_id)
    end
  end
end
