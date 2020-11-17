# frozen_string_literal: true

module UmbrellioUtils
  module Store
    extend self

    include Memery

    def []=(key, value)
      attrs = { key: key.to_s, value: JSON.dump(value), updated_at: Time.current }
      entry.upsert_dataset.insert(attrs)
      clear_cache_for(key)
    end

    def [](key)
      find(key)&.value
    end

    def delete(key)
      result = !!find(key)&.delete
      clear_cache_for(key) if result
      result
    end

    def find(key)
      Rails.cache.fetch(cache_key_for(key)) { entry[key.to_s] }
    end

    memoize def entry
      Sequel::Model(:store)
    end

    private

    def cache_key_for(key)
      "store-entry-#{key}"
    end

    def clear_cache_for(key)
      Rails.cache.delete(cache_key_for(key))
    end
  end
end
