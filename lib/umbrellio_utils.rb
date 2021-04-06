# frozen_string_literal: true

require "memery"

module UmbrellioUtils
  GLOBAL_MUTEX = Mutex.new

  Dir["#{__dir__}/*/*.rb"].each { |file_path| require_relative(file_path) }

  extend self

  def included(othermod)
    super
    othermod.extend(self)
  end

  # rubocop:disable Style/ClassVars
  def config
    synchronize do
      @@config ||= Struct
        .new(:store_table_name, :http_client_name, keyword_init: true)
        .new(**default_settings)
    end
  end

  # rubocop:enable Style/ClassVars

  def configure
    synchronize { yield config }
  end

  def extend_util!(module_name, &block)
    const = UmbrellioUtils.const_get(module_name)
    synchronize { const.class_eval(&block) }
  end

  private

  def default_settings
    {
      store_table_name: :store,
      http_client_name: :application_httpclient,
    }
  end

  def synchronize(&block)
    GLOBAL_MUTEX.owned? ? yield : GLOBAL_MUTEX.synchronize(&block)
  end
end
