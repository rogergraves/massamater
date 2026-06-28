require "rails_helper"

RSpec.describe StoreHour, type: :model do
  describe "validations" do
    subject { build(:store_hour) }

    it { is_expected.to validate_presence_of(:day_of_week) }
    it { is_expected.to validate_uniqueness_of(:day_of_week).ignoring_case_sensitivity }

    it "requires opens_at and closes_at when open" do
      sh = build(:store_hour, open: true, opens_at: nil, closes_at: nil)
      expect(sh).not_to be_valid
      expect(sh.errors[:opens_at]).to be_present
      expect(sh.errors[:closes_at]).to be_present
    end

    it "does not require times when closed" do
      sh = build(:store_hour, open: false, opens_at: nil, closes_at: nil)
      expect(sh).to be_valid
    end
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:day_of_week).with_values(
        sunday: 0, monday: 1, tuesday: 2, wednesday: 3,
        thursday: 4, friday: 5, saturday: 6
      )
    }
  end

  describe ".for_date" do
    it "returns the store hour record for a given date's weekday" do
      tuesday = create(:store_hour, day_of_week: :tuesday)
      date    = Date.new(2026, 6, 23) # a Tuesday
      expect(StoreHour.for_date(date)).to eq(tuesday)
    end
  end
end
