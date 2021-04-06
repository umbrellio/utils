# frozen_string_literal: true

describe UmbrellioUtils::Misc do
  describe "::build_infinite_hash" do
    subject(:hash) { described_class.build_infinite_hash }

    specify { is_expected.to be_an_instance_of(Hash) }

    context "with deep accessing" do
      it "generates new hashes" do
        expect(hash[:key]).to eq({})
        expect(hash[:other_key]).to eq({})
        expect(hash.dig(:kek, :pek, :cheburek)).to eq({})

        expect(hash[:key].object_id).not_to eq(hash[:other_key].object_id)
        expect(hash.keys).to eq(%i[key other_key kek])
      end
    end
  end
end
