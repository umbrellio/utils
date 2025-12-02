# frozen_string_literal: true

require_relative "umbrellio_utils"

if defined?(Rake)
  Dir[File.join(__dir__, "umbrellio_utils/tasks/**/*.rake")].each { |f| load f }
end

if defined?(RSpec)
  Dir[File.join(__dir__, "umbrellio_utils/testing/**/*.rb")].each { |f| require f }
end
