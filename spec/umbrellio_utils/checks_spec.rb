# frozen_string_literal: true

describe UmbrellioUtils::Checks do
  describe "#valid_email?" do
    subject(:result) { described_class.valid_email?(input) }

    expectations = {
      "user@example.com" => true,
      "user@one.two42.com" => true,
      "invalid" => false,
      123 => false,
      nil => false,
    }

    expectations.each do |input, expected_result|
      context "with input #{input.inspect} should return #{expected_result.inspect}" do
        let(:input) { input }
        let(:expected_result) { expected_result }

        it { is_expected.to eq(expected_result) }
      end
    end
  end
end
