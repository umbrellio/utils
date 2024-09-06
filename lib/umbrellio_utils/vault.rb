# frozen_string_literal: true

module UmbrellioUtils
  module Vault
    extend self

    def secret_engine_present?(engine_path)
      ::Vault.logical.read("sys/mounts").data.key?(:"#{engine_path}/")
    end

    def create_kv_engine(path)
      ::Vault.logical.write(
        "sys/mounts/#{path}",
        config: {},
        generate_signing_key: true,
        options: { version: 2 },
        path: path.to_s,
        type: "kv",
      )
    end

    def write_to_kv(engine_path:, secret_path:, data:)
      full_data_path = File.join(engine_path, "data", secret_path)
      full_meta_path = File.join(engine_path, "metadata", secret_path)
      ::Vault.logical.write(full_data_path, data:)
      ::Vault.logical.write(full_meta_path, id: secret_path, max_versions: 1, cas_required: false)
    end
  end
end
