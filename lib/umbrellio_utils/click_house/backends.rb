# frozen_string_literal: true

require_relative "backends/base"

module UmbrellioUtils
  module ClickHouse
    module Backends
      autoload :Legacy, "umbrellio_utils/click_house/backends/legacy"
      autoload :Native, "umbrellio_utils/click_house/backends/native"
    end
  end
end
