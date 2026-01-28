# frozen_string_literal: true

module RuboCop
  module Cop
    module Custom
      class RegexRules < Base
        def on_new_investigation
          return if processed_source.blank?

          rules.each do |rule|
            next unless applies_to_file?(rule)

            regex = Regexp.new(rule["regex"])
            processed_source.raw_source.each_line.with_index(1) do |line, lineno|
              next unless (match = regex.match(line))

              range = range_for_match(lineno, match)
              add_offense(range, message: rule["message"])
            end
          end
        end

        private

        def rules
          cop_config["Rules"] || []
        end

        def applies_to_file?(rule)
          path = processed_source.path.sub("#{Dir.pwd}/", "") # relative path

          # Check exclusions first
          if rule["exclude_paths"]&.any? do |pattern|
            File.fnmatch?(pattern, path)
          end
            return false
          end

          # Then check inclusions
          return true unless rule["paths"] # no restriction

          rule["paths"].any? { |pattern| File.fnmatch?(pattern, path, File::FNM_PATHNAME) }
        end

        def range_for_match(lineno, match)
          buffer = processed_source.buffer
          line_range = buffer.line_range(lineno)
          start_pos = line_range.begin_pos + match.begin(0)
          end_pos = line_range.begin_pos + match.end(0)
          Parser::Source::Range.new(buffer, start_pos, end_pos)
        end
      end
    end
  end
end
