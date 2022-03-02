# frozen_string_literal: true

describe UmbrellioUtils::Control do
  describe "#retry_on_unique_violation" do
    def run!
      described_class.retry_on_unique_violation(
        times: times,
        retry_on_all_constraints: retry_on_all_constraints,
        checked_constraints: checked_constraints,
        &callable_proc
      )
    end

    let(:database_double) do
      double("database").tap do |instance|
        allow(instance).to receive(:transaction) do |kwargs, &block|
          transaction_kwargs << kwargs
          block.call
        end
      end
    end
    let(:transaction_kwargs) { [] }
    let(:violated_constraint_name) { "some_constraint_name" }

    let(:times) { 1 }
    let(:retry_on_all_constraints) { false }
    let(:checked_constraints) { [] }
    let(:callable_proc) { proc {} }

    before { stub_const("DB", database_double) }
    before do
      allow(UmbrellioUtils::Database).to(
        receive(:get_violated_constraint_name).and_return(violated_constraint_name),
      )
    end
    before { stub_const("Sequel::UniqueConstraintViolation", Class.new(StandardError)) }

    it "doesn't use transaction" do
      run!

      expect(transaction_kwargs.size).to eq(0)
    end

    context "when some random error is raised" do
      let(:retry_on_all_constraints) { true }
      let(:callable_proc) { proc { raise StandardError, "cool message" } }

      it "doesn't retries on that error" do
        expect { run! }.to raise_error("cool message")

        expect(transaction_kwargs.size).to eq(1)
      end
    end

    context "when unique constraint is trigerred" do
      let(:callable_proc) { proc { raise Sequel::UniqueConstraintViolation, "msg" } }

      it "raises UniqueConstraintViolation" do
        expect { run! }.to raise_error(described_class::UniqueConstraintViolation, "msg")

        expect(transaction_kwargs.size).to eq(0)
      end

      context "when retrying on all constraints" do
        let(:retry_on_all_constraints) { true }

        it "uses savepoint and raises error" do
          expect { run! }.to raise_error(described_class::UniqueConstraintViolation, "msg")

          expect(transaction_kwargs.size).to eq(2)
          expect(transaction_kwargs.first[:savepoint]).to eq(true)
          expect(transaction_kwargs.last[:savepoint]).to eq(true)
        end
      end

      context "when retrying on this constraint" do
        let(:checked_constraints) { %w[some_constraint_name] }

        it "uses savepoint and raises error" do
          expect { run! }.to raise_error(described_class::UniqueConstraintViolation)

          expect(transaction_kwargs.size).to eq(2)
          expect(transaction_kwargs.first[:savepoint]).to eq(true)
          expect(transaction_kwargs.last[:savepoint]).to eq(true)
        end
      end

      context "when retrying on different constraint" do
        let(:checked_constraints) { %w[other_constraint] }

        it "uses savepoint and raises error" do
          expect { run! }.to raise_error(described_class::UniqueConstraintViolation)

          expect(transaction_kwargs.size).to eq(1)
          expect(transaction_kwargs.first[:savepoint]).to eq(true)
        end
      end
    end
  end
end
