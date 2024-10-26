# frozen_string_literal: true

describe UmbrellioUtils::Checks do
  describe "#valid_email?" do
    subject(:result) { described_class.valid_email?(input) }

    let(:input) { "user@example.com" }

    it { is_expected.to eq(true) }

    context "invalid input" do
      let(:input) { "invalid" }

      it { is_expected.to eq(false) }
    end

    context "input with subdomains and digits" do
      let(:input) { "user@one.two42.com" }

      it { is_expected.to eq(true) }
    end

    context "non-string input" do
      let(:input) { 123 }

      it { is_expected.to eq(false) }
    end
  end
end
