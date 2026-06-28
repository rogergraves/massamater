require "rails_helper"

RSpec.describe StoreException, type: :model do
  describe "validations" do
    subject { build(:store_exception) }

    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_uniqueness_of(:date) }
    it { is_expected.to validate_presence_of(:reason) }

    it "requires opens_at and closes_at when not closed" do
      exc = build(:store_exception, closed: false, opens_at: nil, closes_at: nil)
      expect(exc).not_to be_valid
      expect(exc.errors[:opens_at]).to be_present
      expect(exc.errors[:closes_at]).to be_present
    end

    it "does not require times when closed" do
      exc = build(:store_exception, closed: true, opens_at: nil, closes_at: nil)
      expect(exc).to be_valid
    end
  end

  describe ".for_date" do
    it "returns the exception for a given date" do
      exception = create(:store_exception, date: Date.new(2026, 12, 25))
      expect(StoreException.for_date(Date.new(2026, 12, 25))).to eq(exception)
    end

    it "returns nil when no exception exists" do
      expect(StoreException.for_date(Date.new(2026, 12, 26))).to be_nil
    end
  end
end
