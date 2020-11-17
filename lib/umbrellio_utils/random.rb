# frozen_string_literal: true

module UmbrellioUtils
  module Random
    extend self

    def uuid
      SecureRandom.uuid
    end
  end
end
