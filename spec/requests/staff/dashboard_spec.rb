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
end
