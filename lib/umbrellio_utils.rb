# frozen_string_literal: true

require "memery"

module UmbrellioUtils
  GLOBAL_MUTEX = Mutex.new

  extend self

  def included(othermod)
    super
    othermod.extend(self)
  end

  # rubocop:disable Style/ClassVars
  def config
    synchronize do
      @@config ||= Struct
        .new(:store_table_name, :http_client_name, :ch_optimize_timeout, keyword_init: true)
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
      ch_optimize_timeout: 5.minutes,
    }
  end

  def synchronize(&)
    GLOBAL_MUTEX.owned? ? yield : GLOBAL_MUTEX.synchronize(&)
  end
end

require_relative "umbrellio_utils/cards"
require_relative "umbrellio_utils/checks"
require_relative "umbrellio_utils/click_house"
require_relative "umbrellio_utils/constants"
require_relative "umbrellio_utils/control"
require_relative "umbrellio_utils/database"
require_relative "umbrellio_utils/formatting"
require_relative "umbrellio_utils/http_client"
require_relative "umbrellio_utils/jobs"
require_relative "umbrellio_utils/migrations"
require_relative "umbrellio_utils/misc"
require_relative "umbrellio_utils/parsing"
require_relative "umbrellio_utils/passwords"
require_relative "umbrellio_utils/random"
require_relative "umbrellio_utils/request_wrapper"
require_relative "umbrellio_utils/rounding"
require_relative "umbrellio_utils/sql"
require_relative "umbrellio_utils/semantic_logger/tiny_json_formatter"
require_relative "umbrellio_utils/store"
require_relative "umbrellio_utils/vault"
require_relative "umbrellio_utils/version"
