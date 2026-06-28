require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:reservations).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:phone) }
    it { is_expected.to validate_uniqueness_of(:phone).ignoring_case_sensitivity }
    it { is_expected.to validate_presence_of(:name) }

    it "requires E.164 phone format" do
      user = build(:user, phone: "912345678")
      expect(user).not_to be_valid
      expect(user.errors[:phone]).to include("must be in E.164 format (+country code)")
    end

    it "accepts valid E.164 phone" do
      user = build(:user, phone: "+351912345678")
      expect(user).to be_valid
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:contact_channel).with_values(sms: 0, whatsapp: 1) }
  end

  describe "#staff?" do
    it "returns true when password_digest is present" do
      user = build(:user, :staff)
      expect(user.staff?).to be true
    end

    it "returns false when password_digest is blank" do
      user = build(:user, password_digest: nil)
      expect(user.staff?).to be false
    end
  end
end
