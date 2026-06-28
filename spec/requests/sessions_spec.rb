require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let!(:staff) { create(:user, :staff, phone: "+351912000001", name: "Staff") }

  describe "POST /login" do
    it "logs in a staff user with correct credentials" do
      post login_path, params: { phone: staff.phone, password: "password" }
      expect(response).to redirect_to(staff_root_path)
      follow_redirect!
      expect(response).to be_successful
    end

    it "rejects wrong password" do
      post login_path, params: { phone: staff.phone, password: "wrong" }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects a non-staff user (no password_digest)" do
      customer = create(:user, phone: "+351912000002")
      post login_path, params: { phone: customer.phone, password: "anything" }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /logout" do
    it "clears the session and redirects to root" do
      post login_path, params: { phone: staff.phone, password: "password" }
      delete logout_path
      expect(response).to redirect_to(root_path)
    end
  end
end
