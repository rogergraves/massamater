require "rails_helper"

RSpec.describe Product, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:product_schedule_days).dependent(:destroy) }
    it { is_expected.to have_many(:daily_inventories).dependent(:destroy) }
    it { is_expected.to have_many(:reservation_items).dependent(:restrict_with_error) }
    it { is_expected.to have_one_attached(:photo) }
    it { is_expected.to have_one_attached(:icon) }
  end

  describe "validations" do
    subject { build(:product) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:default_ready_time) }
    it { is_expected.to validate_numericality_of(:default_daily_batch_size).is_greater_than(0) }
    it {
      is_expected.to validate_numericality_of(:max_reservable_quantity_per_client)
        .is_greater_than(0)
        .allow_nil
    }
  end

  describe "#display_name" do
    let(:product) { build(:product, name: "Baguete", name_en: "Baguette") }

    it "returns Portuguese name when locale is :pt" do
      I18n.with_locale(:pt) { expect(product.display_name).to eq("Baguete") }
    end

    it "returns English name when locale is :en and name_en is present" do
      I18n.with_locale(:en) { expect(product.display_name).to eq("Baguette") }
    end

    it "falls back to Portuguese name when locale is :en but name_en is blank" do
      product.name_en = nil
      I18n.with_locale(:en) { expect(product.display_name).to eq("Baguete") }
    end
  end

  describe "scopes" do
    it ".active returns only active products" do
      active   = create(:product, active: true)
      inactive = create(:product, active: false)
      expect(Product.active).to include(active)
      expect(Product.active).not_to include(inactive)
    end

    it ".ordered sorts by order then name" do
      b = create(:product, name: "B", order: 2)
      a = create(:product, name: "A", order: 1)
      expect(Product.ordered.to_a).to eq([a, b])
    end
  end
end
