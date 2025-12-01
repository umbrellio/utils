# frozen_string_literal: true

require_relative "umbrellio_utils"

if defined?(Rake)
  Dir[File.join(__dir__, "tasks/**/*.rake")].each { |f| load f }
end
