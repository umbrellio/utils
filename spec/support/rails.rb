# frozen_string_literal: true

module Rails
  def self.env
    "development".inquiry
  end

  def self.logger
    nil
  end
end
