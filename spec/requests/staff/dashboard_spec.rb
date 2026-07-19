require "rails_helper"

RSpec.describe "Staff::Dashboard", type: :request do
  let(:staff) { create(:user, :staff, phone: "+351910000099") }

  before { post login_path, params: { phone: staff.phone, password: "password" } }

  describe "GET /staff" do
    it "returns 200" do
      get staff_root_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "authentication" do
    it "redirects to login when not authenticated" do
      delete logout_path
      get staff_root_path
      expect(response).to redirect_to(login_path)
    end
  end

  describe "closed day" do
    context "when today is closed" do
      before do
        allow(Date).to receive(:current).and_return(Date.new(2026, 7, 20)) # Monday
        StoreException.create!(date: Date.new(2026, 7, 20), reason: "Holiday", closed: true)
        StoreHour.create!(day_of_week: :wednesday, open: true, opens_at: "09:00", closes_at: "17:00")
      end

      it "returns 200 and shows the closed notice" do
        get staff_root_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("staff.dashboard.closed_today"))
      end
    end
  end
end
