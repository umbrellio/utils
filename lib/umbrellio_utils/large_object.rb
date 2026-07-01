# frozen_string_literal: true

module UmbrellioUtils
  class LargeObject
    FILE_END = 2
    PG_PAGE_SIZE = 8 * 1024

    class AlreadyExists < StandardError
    end

    autoload :Writer, "umbrellio_utils/large_object/writer"

    attr_reader :oid
    attr_accessor :str_offset

    def initialize(oid = -1)
      self.oid = oid
      self.str_offset = 0
    end

    def create!
      run(:lo_create, oid)
    rescue Sequel::UniqueConstraintViolation
      raise AlreadyExists.new
    end

    def open_to_write!
      DB.transaction do
        fd = run(:lo_open, oid, 0x60000)
        self.str_offset = run(:lo_lseek, fd, 0, FILE_END)
      end
    end

    def append!(str)
      run(:lo_put, oid, str_offset, Sequel.blob(str))
      self.str_offset += str.length
    end

    def read(*)
      run(:lo_get, oid, *)
    end

    def delete!
      run(:lo_unlink, oid) if exists?
    end

    def exists?
      DB[:pg_largeobject_metadata].first(oid:).present?
    end

    private

    attr_writer :oid

    def run(method_name, *)
      DB.get(Sequel.function(method_name, *))
    end
  end
end
