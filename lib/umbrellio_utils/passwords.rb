# frozen_string_literal: true

module UmbrellioUtils
  module Passwords
    extend self

    def check(hash, password)
      SCrypt::Password.new(hash).is_password?(password)
    end

    def create_hash(password)
      SCrypt::Password.create(password).to_s
    end
  end
end
