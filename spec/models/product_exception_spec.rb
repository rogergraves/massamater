require "rails_helper"

RSpec.describe ProductException, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:product) }
  end

  describe "validations" do
    subject { build(:product_exception) }

    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_uniqueness_of(:date).scoped_to(:product_id) }
    it { is_expected.to validate_numericality_of(:batch_size).is_greater_than_or_equal_to(1).allow_nil }

    context "when added is true" do
      subject { build(:product_exception, :added) }
      it { is_expected.to validate_presence_of(:batch_size) }
    end
  end

  describe "#effective_ready_time" do
    let(:product) { build(:product, default_ready_time: "09:00") }

    it "returns the override when set" do
      exc = build(:product_exception, product: product, ready_time_override: "11:30")
      expect(exc.effective_ready_time.strftime("%H:%M")).to eq("11:30")
    end

    it "falls back to the product default when no override" do
      exc = build(:product_exception, product: product, ready_time_override: nil)
      expect(exc.effective_ready_time.strftime("%H:%M")).to eq("09:00")
    end
  end
end
