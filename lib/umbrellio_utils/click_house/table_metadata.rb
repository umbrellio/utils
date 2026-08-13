# frozen_string_literal: true

module UmbrellioUtils
  module ClickHouse
    # Layout of a ReplacingMergeTree table, read out of `system.tables`.
    #
    # ReplacingMergeTree collapses rows sharing the full sorting key, keeping
    # the one with the highest version and dropping it entirely when the
    # is_deleted column is set. `Dataset#deduplicate` reproduces that by hand,
    # so it needs all three parts.
    TableMetadata = Struct.new(:sorting_key, :version, :is_deleted)

    # Reopened rather than declared with a block: constants defined inside a
    # `Struct.new do ... end` block leak to the enclosing lexical scope.
    class TableMetadata
      class UnsupportedEngine < StandardError
      end

      class UnknownTable < StandardError
      end

      REPLICATED_ARGS_COUNT = 2 # zookeeper path + replica name

      class << self
        def parse(engine:, engine_full:, sorting_key:)
          unless engine.include?("Replacing")
            raise UnsupportedEngine,
                  "#{engine} is not a ReplacingMergeTree; deduplicate is not applicable"
          end

          args = engine_args(engine_full)
          args = args.drop(REPLICATED_ARGS_COUNT) if engine.start_with?("Replicated")

          new(split_args(sorting_key), args[0]&.to_sym, args[1]&.to_sym)
        end

        # Distributed('cluster', 'database', 'table'[, sharding_key])
        def distributed_target(engine_full)
          _cluster, database, table = engine_args(engine_full)
          [unquote(database), unquote(table)]
        end

        # Arguments of the leading engine call, or [] when the engine takes none.
        # Only a parenthesis directly after the engine name counts — later
        # clauses such as `PARTITION BY toYYYYMM(created_at)` must not be read.
        def engine_args(engine_full)
          open_index = engine_full.index("(")
          return [] unless open_index
          return [] unless engine_full[0...open_index].match?(/\A\w+\z/)

          split_args(engine_full[(open_index + 1)...close_index(engine_full, open_index)])
        end

        # Split on top-level commas only: sorting keys hold function calls and
        # engine arguments hold quoted paths, both of which may contain commas.
        def split_args(source)
          args = []
          current = +""
          depth = 0
          in_string = false

          source.to_s.each_char do |char|
            case char
            when "'" then in_string = !in_string
            when "(" then depth += 1 unless in_string
            when ")" then depth -= 1 unless in_string
            when ","
              if depth.zero? && !in_string
                args << current.strip
                current = +""
                next
              end
            end

            current << char
          end

          args << current.strip
          args.reject(&:empty?)
        end

        private

        def close_index(source, open_index)
          depth = 0

          source[open_index..].each_char.with_index(open_index) do |char, index|
            depth += 1 if char == "("
            depth -= 1 if char == ")"
            return index if depth.zero?
          end

          raise UnsupportedEngine, "unbalanced parentheses in engine: #{source}"
        end

        def unquote(value)
          value.to_s.delete_prefix("'").delete_suffix("'")
        end
      end
    end
  end
end
