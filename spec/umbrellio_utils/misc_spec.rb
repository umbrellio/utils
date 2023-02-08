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
      described_class.table_sync(users)
    end

    def expect_user_publishing(user_id)
      expect(TableSync::Publishing::Batch).to have_received(:new).with(
        object_class: "User",
        original_attributes: [{ id: user_id, email: "user#{user_id}@mail.com" }],
        routing_key: nil,
      )
    end

    before do
      User.create(email: "user1@mail.com")
      User.create(email: "user2@mail.com")
      Array.alias_method(:in_batches, :each)
      stub_const("TableSync::Publishing::Batch", table_sync_stub)
    end

    let(:users) do
      [
        User.where(id: 1),
        User.where(id: 2),
      ]
    end

    let(:table_sync_stub) do
      class_double("TableSync::Publishing::Batch").tap do |klass|
        allow(klass).to receive(:new).and_return(publisher)
      end
    end

    let(:publisher) do
      instance_double("TableSync::Publishing::Batch").tap do |instance|
        allow(instance).to receive(:publish_now)
      end
    end

    context "without skipped users" do
      before do
        User.define_method(:skip_table_sync?) { false }
      end

      it "publishes all data" do
        run!

        expect_user_publishing(1)
        expect_user_publishing(2)
        expect(publisher).to have_received(:publish_now).exactly(2).times
      end
    end

    context "with skipped users" do
      before do
        User.define_method(:skip_table_sync?) do
          self.id == 1
        end
      end

      it "publishes only second user's data" do
        run!

        expect_user_publishing(2)
        expect(publisher).to have_received(:publish_now)
      end
    end
  end
end
