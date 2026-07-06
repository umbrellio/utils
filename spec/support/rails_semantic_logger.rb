# frozen_string_literal: true

# Minimal stub of the rails_semantic_logger class patched by
# UmbrellioUtils::Patches::RailsSemanticLogger, so that specs don't have to load
# the whole Rails stack.
module RailsSemanticLogger
  module ActionController
    class LogSubscriber
      private

      def extract_path(path)
        index = path.index("?")
        index ? path[0, index] : path
      end
    end
  end
end
