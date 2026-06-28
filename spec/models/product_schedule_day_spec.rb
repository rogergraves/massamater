require "rails_helper"

RSpec.describe ProductScheduleDay, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:product) }
  end

  describe "validations" do
    subject { build(:product_schedule_day) }

    it { is_expected.to validate_presence_of(:day_of_week) }
    it {
      is_expected.to validate_uniqueness_of(:day_of_week)
        .scoped_to(:product_id)
        .ignoring_case_sensitivity
    }
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:day_of_week).with_values(
        sunday: 0, monday: 1, tuesday: 2, wednesday: 3,
        thursday: 4, friday: 5, saturday: 6
      )
    }
  end
end
