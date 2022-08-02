# frozen_string_literal: true

module Rails
  def self.env
    "development".inquiry
  end
end
