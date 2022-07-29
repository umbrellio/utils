# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    # Make Postgres return rows truly randomly in specs unless order is properly specified
    class Sequel::Postgres::Dataset # rubocop:disable Lint/ConstantDefinitionInBlock
      def select_sql
        return super if @opts[:_skip_order_patch]
        order = @opts[:order].dup || []
        order << Sequel.function(:random)
        clone(order: order, _skip_order_patch: true).select_sql
      end
    end
  end
end
