# frozen_string_literal: true

require "memery"

module UmbrellioUtils
  CONFIG_SET_MUTEX = Mutex.new
  CONFIG_MUTEX = Mutex.new
  EXTENSION_MUTEX = Mutex.new

  Dir["#{__dir__}/*/*.rb"].each { |file_path| require_relative(file_path) }

  extend self

  def included(othermod)
    super
    othermod.extend(self)
  end

  # rubocop:disable Style/ClassVars
  def config
    CONFIG_SET_MUTEX.synchronize do
      @@config ||= Struct
        .new(:store_table_name, :http_client_name, keyword_init: true)
        .new(**default_settings)
    end
  end

  # rubocop:enable Style/ClassVars

  def configure
    CONFIG_MUTEX.synchronize { yield config }
  end

  def extend_util!(module_name, &block)
    const = UmbrellioUtils.const_get(module_name)
    EXTENSION_MUTEX.synchronize { const.class_eval(&block) }
  end

  private

  def default_settings
    {
      store_table_name: :store,
      http_client_name: :application_httpclient,
    }
  end
end
