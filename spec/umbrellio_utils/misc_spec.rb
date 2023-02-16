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

  describe "::table_sync" do
    def run!
      described_class.table_sync(users, routing_key: :umbrellio_utils)
    end

    before do
      User.define_method(:skip_table_sync?) { nil }
      User.create(email: "user1@mail.com")
      User.create(email: "user2@mail.com")
    end

    let(:rabbit_data) do
      {
        confirm_select: true,
        data: {
          attributes: expected_rabbit_attributes,
          event: :update,
          metadata: { created: false },
          model: "User",
          version: Numeric,
        },
        event: :table_sync,
        exchange_name: nil,
        headers: {},
        realtime: true,
        routing_key: :umbrellio_utils,
      }
    end

    let(:users) { User.where(id: [1, 2]) }

    context "without skipped users" do
      before do
        allow_any_instance_of(User).to receive(:skip_table_sync?).and_return(false)
      end

      let(:expected_rabbit_attributes) do
        [
          { email: "user1@mail.com", id: 1 },
          { email: "user2@mail.com", id: 2 },
        ]
      end

      it "publishes all data" do
        expect_rabbit_message(rabbit_data)

        run!
      end
    end

    context "when first user should be skipped" do
      before do
        allow_any_instance_of(User).to receive(:skip_table_sync?) do |user|
          user.id == 1
        end
      end

      let(:expected_rabbit_attributes) do
        [{ email: "user2@mail.com", id: 2 }]
      end

      it "publishes only second user's data" do
        expect_rabbit_message(rabbit_data)

        run!
      end
    end

    context "when all users should be skipped" do
      before do
        allow_any_instance_of(User).to receive(:skip_table_sync?).and_return(true)
      end

      it "doesn't publish message" do
        expect_no_rabbit_messages

        run!
      end
    end
  end
end
