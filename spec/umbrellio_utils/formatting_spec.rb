# frozen_string_literal: true

describe UmbrellioUtils::Formatting do
  describe "::expand_hash" do
    subject(:expanded_hash) { described_class.expand_hash(hash, **kwargs) }

    let(:hash) { Hash["deep.first": true, "deep.second": false, root: "kek"] }
    let(:kwargs) { Hash[] }

    specify { is_expected.to eq(deep: { first: true, second: false }, root: "kek") }

    context "with other delimiter" do
      let(:hash) { Hash["deep,first": true, "deep,second": false, root: "kek"] }
      let(:kwargs) { Hash[delemiter: ","] }

      specify { is_expected.to eq(deep: { first: true, second: false }, root: "kek") }
    end

    context "with custom key converter" do
      let(:kwargs) { Hash[key_converter: :to_s] }

      specify do
        is_expected.to eq("deep" => { "first" => true, "second" => false }, "root" => "kek")
      end
    end
  end
end
