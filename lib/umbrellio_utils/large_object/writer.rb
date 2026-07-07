# frozen_string_literal: true

module UmbrellioUtils
  class LargeObject
    # :nocov:
    class Writer
      MAX_BUFFER_SIZE = PG_PAGE_SIZE * 10

      attr_reader :large_object

      def initialize(large_object)
        @large_object = large_object
        self.sio = StringIO.new.binmode
        super()

        if block_given?
          yield(self)
          flush
        end
      end

      def flush
        sio.flush
        large_object.append!(sio.string)
        sio.truncate(0)
        sio.rewind
        self
      end

      def tell
        sio.tell + large_object.str_offset
      end
      alias pos tell

      def write(*)
        sio.write(*)
        flush if sio.string.size >= MAX_BUFFER_SIZE
        self
      end
      alias << write

      def reopen(other, *)
        sio.reopen(other.sio.string, *)
        self
      end

      def pos=(new_pos)
        case
        when new_pos < large_object.str_offset
          flush
          relative_pos = new_pos - large_object.str_offset
          large_object.str_offset += relative_pos
        when new_pos > sio.string.length
          flush
          large_object.str_offset = new_pos
        else
          sio.pos = new_pos - large_object.str_offset
        end
      end

      def rewind
        large_object.str_offset = 0
        sio.rewind
      end

      protected

      attr_accessor :sio
    end
    # :nocov:
  end
end
