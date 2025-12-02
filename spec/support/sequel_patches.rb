# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    # Make Postgres return rows truly randomly in specs unless order is properly specified
    class Sequel::Postgres::Dataset # rubocop:disable Lint/ConstantDefinitionInBlock
      def select_sql
        return super if @opts[:_skip_order_patch] || @opts[:append_sql]
        return super if @opts[:ch] && @opts[:order].present?
        order = @opts[:order].dup || []
        fn = @opts.key?(:ch) ? :rand : :random
        order << Sequel.function(fn)
        clone(order:, _skip_order_patch: true).select_sql
      end
    end
  end
end
