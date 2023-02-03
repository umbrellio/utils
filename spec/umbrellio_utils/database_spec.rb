# frozen_string_literal: true

describe UmbrellioUtils::Database, db: true do
  describe "#create_temp_table" do
    before do
      Timecop.freeze("2021-12-06 UTC")
      allow(DB).to receive(:create_table).with(table_name, unlogged: true).and_call_original
    end

    let!(:users) do
      [
        User.create(email: "user1@mail.com"),
        User.create(email: "user2@mail.com"),
      ]
    end

    let(:table_name) { :temp_users_1638748800_0 }

    subject(:result) do
      described_class.create_temp_table(User.dataset, primary_key: :id)
    end

    specify do
      expect(result).to eq(table_name)
      expect(DB[table_name].select_map(:id)).to match_array(users.map(&:id))
    end
  end

  describe "#each_record" do
    before do
      User.multi_insert(users_data)
      allow(Kernel).to receive(:sleep) { |value| sleep_calls << value }
    end

    let(:sleep_calls) { [] }
    let(:options) { Hash[] }

    let(:users_data) do
      Array.new(10) { |index| Hash[email: "user#{index + 1}@email.com"] }
    end

    let(:reversed_emails) { users_data.pluck(:email).reverse }

    subject(:result_emails) do
      users = []

      described_class.each_record(User.dataset, **options) do |user|
        users << user
      end

      users.map(&:email)
    end

    it "yields each record in reversed order" do
      expect(result_emails).to eq(reversed_emails)
      expect(sleep_calls).to eq([])
    end

    context "smaller page_size and numeric sleep value" do
      let(:options) { Hash[page_size: 3, sleep: 10] }

      it "calls Kernel.sleep between pages" do
        expect(result_emails).to eq(reversed_emails)
        expect(sleep_calls).to eq([10, 10, 10, 10])
      end
    end

    context "production Rails env" do
      before { allow(Rails).to receive(:env).and_return("production".inquiry) }

      it "calls Kernel.sleep" do
        expect(result_emails).to eq(reversed_emails)
        expect(sleep_calls).to eq([1])
      end

      context "false sleep option" do
        let(:options) { Hash[sleep: false] }

        it "doesn't call Kernel.sleep" do
          expect(result_emails).to eq(reversed_emails)
          expect(sleep_calls).to eq([])
        end
      end
    end
  end
end
