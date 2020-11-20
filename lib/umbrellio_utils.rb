# frozen_string_literal: true

require "active_support/all"
require "memery"

module UmbrellioUtils
  Dir["#{__dir__}/*/*.rb"].each { |file_path| require_relative(file_path) }

  extend self
end
