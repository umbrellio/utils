# frozen_string_literal: true

require "umbrellio_utils/patches/active_support_event"

describe UmbrellioUtils::Patches::ActiveSupportEvent do
  let(:event) do
    ActiveSupport::Notifications::Event.new("some.event", nil, nil, "42", {})
  end

  it "tracks GVL time and malloc stats between start! and finish!" do
    event.start!
    Array.new(100) { "x" * 100 }
    event.finish!

    expect(event.gvl_time).to be_a(Float)
    expect(event.gvl_time).to be >= 0
    expect(event.malloc_increase_bytes).to be_an(Integer)
  end

  it "returns zero values for a non-started event" do
    expect(event.gvl_time).to eq(0.0)
    expect(event.malloc_increase_bytes).to eq(0)
  end
end
