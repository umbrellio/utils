# frozen_string_literal: true

require "gvltools"
require "active_support/notifications"

module UmbrellioUtils
  # Namespace for opt-in monkey-patches. None of these files are loaded by default,
  # require them explicitly from your application.
  module Patches
    # Extends ActiveSupport::Notifications::Event with GVL wait time and malloc stats.
    # https://github.com/rails/rails/blob/main/activesupport/lib/active_support/notifications/instrumenter.rb # rubocop:disable Layout/LineLength
    #
    # The GVL timer must be enabled in the application as early as possible:
    #   GVLTools::LocalTimer.enable
    module ActiveSupportEvent
      def initialize(...)
        super
        @gvl_time_start = 0
        @gvl_time_finish = 0
        @malloc_increase_bytes_start = 0
        @malloc_increase_bytes_finish = 0
      end

      def start!
        super
        @gvl_time_start = GVLTools::LocalTimer.monotonic_time
        @malloc_increase_bytes_start = GC.stat(:malloc_increase_bytes)
      end

      def finish!
        super
        @gvl_time_finish = GVLTools::LocalTimer.monotonic_time
        @malloc_increase_bytes_finish = GC.stat(:malloc_increase_bytes)
      end

      # Time the thread spent waiting for the GVL, in milliseconds
      def gvl_time
        (@gvl_time_finish - @gvl_time_start) / 1_000_000.0
      end

      # Delta of the process-global malloc counter: can be negative (it resets on GC)
      # and includes sibling threads' allocations under threaded servers. Guard with
      # #positive? where a counter is expected.
      def malloc_increase_bytes
        @malloc_increase_bytes_finish - @malloc_increase_bytes_start
      end
    end
  end
end

ActiveSupport::Notifications::Event.prepend(UmbrellioUtils::Patches::ActiveSupportEvent)
