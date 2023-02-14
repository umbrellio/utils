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

    def rabbit_data(user_id:)
      {
        confirm_select: true,
        data: {
          attributes: [{ email: "user#{user_id}@mail.com", id: user_id }],
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

    before do
      User.create(email: "user1@mail.com")
      User.create(email: "user2@mail.com")
      Array.alias_method(:in_batches, :each)
    end

    let(:users) do
      [
        User.where(id: 1),
        User.where(id: 2),
      ]
    end

    context "without skipped users" do
      before do
        User.define_method(:skip_table_sync?) { false }
      end

      it "publishes all data" do
        expect_rabbit_message(rabbit_data(user_id: 1))
        expect_rabbit_message(rabbit_data(user_id: 2))

        run!
      end
    end

    context "with skipped users" do
      before do
        User.define_method(:skip_table_sync?) do
          self.id == 1
        end
      end

      it "publishes only second user's data" do
        expect_rabbit_message(rabbit_data(user_id: 2))
        expect(Rabbit).not_to receive(:publish).with(rabbit_data(user_id: 1))

        run!
      end
    end
  end
end
