require "rails_helper"

RSpec.describe "Staff::Customers", type: :request do
  let(:staff) { create(:user, :staff, phone: "+351910000099") }

  before do
    post login_path, params: { phone: staff.phone, password: "password" }
  end

  describe "GET /staff/customers/lookup" do
    context "when customer exists" do
      let!(:customer) do
        User.create!(phone: "+351912345678", name: "Ana Costa")
      end

      it "returns found: true with name and last source" do
        res = Reservation.create!(user: customer, date: Date.tomorrow, source: :counter)
        get staff_customer_lookup_path, params: { phone: "+351912345678" }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["found"]).to eq(true)
        expect(json["name"]).to eq("Ana Costa")
        expect(json["source"]).to eq("counter")
      end

      it "defaults to phone source when customer has no reservations" do
        get staff_customer_lookup_path, params: { phone: "+351912345678" }
        json = JSON.parse(response.body)
        expect(json["source"]).to eq("phone")
      end
    end

    context "when customer does not exist" do
      it "returns found: false with phone source default" do
        get staff_customer_lookup_path, params: { phone: "+351999000001" }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["found"]).to eq(false)
        expect(json["source"]).to eq("phone")
      end
    end

    it "redirects when not authenticated" do
      delete logout_path
      get staff_customer_lookup_path, params: { phone: "+351912345678" }
      expect(response).to redirect_to(login_path)
    end
  end
end
