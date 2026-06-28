require "rails_helper"

RSpec.describe Reservation, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:reservation_items).dependent(:destroy) }
    it { is_expected.to have_many(:products).through(:reservation_items) }
  end

  describe "validations" do
    subject { build(:reservation) }

    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:source) }
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:source).with_values(
        sms: 0, whatsapp: 1, phone: 2, counter: 3, online: 4
      )
    }
  end

  describe "scopes" do
    let!(:upcoming)  { create(:reservation, cancelled: false, collected_at: nil, date: Date.tomorrow) }
    let!(:collected) { create(:reservation, cancelled: false, collected_at: Time.current, date: Date.yesterday) }
    let!(:cancelled) { create(:reservation, cancelled: true) }

    it ".active excludes cancelled" do
      expect(Reservation.active).to include(upcoming, collected)
      expect(Reservation.active).not_to include(cancelled)
    end

    it ".upcoming returns active, uncollected, future-or-today reservations" do
      expect(Reservation.upcoming).to include(upcoming)
      expect(Reservation.upcoming).not_to include(collected, cancelled)
    end

    it ".collected returns active and collected" do
      expect(Reservation.collected).to include(collected)
      expect(Reservation.collected).not_to include(upcoming, cancelled)
    end
  end

  describe "#collected?" do
    it "returns true when collected_at is set" do
      r = build(:reservation, collected_at: Time.current)
      expect(r.collected?).to be true
    end

    it "returns false when collected_at is nil" do
      r = build(:reservation, collected_at: nil)
      expect(r.collected?).to be false
    end
  end

  describe "#cancellable?" do
    it "returns true when not collected and not cancelled" do
      r = build(:reservation, collected_at: nil, cancelled: false)
      expect(r.cancellable?).to be true
    end

    it "returns false when already collected" do
      r = build(:reservation, collected_at: Time.current, cancelled: false)
      expect(r.cancellable?).to be false
    end

    it "returns false when already cancelled" do
      r = build(:reservation, collected_at: nil, cancelled: true)
      expect(r.cancellable?).to be false
    end
  end
end
