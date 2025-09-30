# frozen_string_literal: true

describe UmbrellioUtils::Rounding do
  describe "#fancy_round" do
    subject(:rounded_number) { described_class.fancy_round(number, **kwargs) }

    let(:number) { 122.12 }
    let(:kwargs) { {} }

    context "with the round method" do
      specify { expect(rounded_number).to eq(100.0) }
    end

    context "with the ceil method" do
      let(:kwargs) { Hash[rounding_method: :ceil] }

      specify { expect(rounded_number).to eq(150.0) }
    end

    context "with an ugliness_level passed in params" do
      let(:kwargs) { Hash[ugliness_level: 2] }

      specify { expect(rounded_number).to eq(125.0) }
    end

    context "with a negative number" do
      let(:number) { -122.12 }

      specify { expect(rounded_number).to eq(0) }
    end
  end

  describe "#super_round" do
    subject(:rounded_number) { described_class.super_round(number, **kwargs) }

    let(:number) { 3221.53 }
    let(:kwargs) { {} }

    context "with the round method" do
      specify { expect(rounded_number).to eq(2500.0) }
    end

    context "with the ceil method" do
      let(:kwargs) { Hash[rounding_method: :ceil] }

      specify { expect(rounded_number).to eq(5000.0) }
    end

    context "with specific targets passed in params" do
      let(:kwargs) { Hash[targets: [1.5, 2.5, 3.5, 5.0]] }

      specify { expect(rounded_number).to eq(3500.0) }
    end

    context "with a negative number" do
      let(:number) { -122.12 }

      specify { expect(rounded_number).to eq(0) }
    end
  end
end
