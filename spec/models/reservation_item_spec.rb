require "rails_helper"

RSpec.describe ReservationItem, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:reservation) }
    it { is_expected.to belong_to(:product) }
  end

  describe "validations" do
    subject { build(:reservation_item) }

    it { is_expected.to validate_numericality_of(:quantity).is_greater_than(0) }
    it { is_expected.to validate_uniqueness_of(:product_id).scoped_to(:reservation_id) }
  end
end
