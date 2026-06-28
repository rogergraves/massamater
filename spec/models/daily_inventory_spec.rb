require "rails_helper"

RSpec.describe DailyInventory, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:product) }
  end

  describe "validations" do
    subject { build(:daily_inventory) }

    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_uniqueness_of(:date).scoped_to(:product_id) }
    it { is_expected.to validate_numericality_of(:batch_size).is_greater_than_or_equal_to(0) }
  end

  describe "#effective_ready_time" do
    let(:product) { build(:product, default_ready_time: "09:00") }

    it "returns the override when set" do
      inv = build(:daily_inventory, product: product, ready_time_override: "11:30")
      expect(inv.effective_ready_time.strftime("%H:%M")).to eq("11:30")
    end

    it "falls back to the product default when no override" do
      inv = build(:daily_inventory, product: product, ready_time_override: nil)
      expect(inv.effective_ready_time.strftime("%H:%M")).to eq("09:00")
    end
  end

  describe ".for_product_on" do
    it "returns existing record" do
      product = create(:product)
      inv     = create(:daily_inventory, product: product, date: Date.today)
      expect(DailyInventory.for_product_on(product, Date.today)).to eq(inv)
    end

    it "initializes a new record with default batch size when none exists" do
      product = create(:product, default_daily_batch_size: 10)
      inv = DailyInventory.for_product_on(product, Date.tomorrow)
      expect(inv).to be_new_record
      expect(inv.batch_size).to eq(10)
    end
  end
end
