require "rails_helper"

RSpec.describe "Staff::StoreExceptions", type: :request do
  let(:staff) { create(:user, :staff, phone: "+351910000088") }

  before do
    post login_path, params: { phone: staff.phone, password: "password" }
  end

  describe "POST /staff/store_exceptions" do
    it "creates a closed exception and redirects to edit store hours" do
      post staff_store_exceptions_path, params: {
        store_exception: {
          date:   Date.current + 7,
          reason: "Bank holiday",
          closed: "1"
        }
      }
      expect(response).to redirect_to(edit_staff_store_hours_path)
      expect(StoreException.last.reason).to eq("Bank holiday")
      expect(StoreException.last.closed).to be true
    end

    it "creates a different-hours exception" do
      post staff_store_exceptions_path, params: {
        store_exception: {
          date:      Date.current + 14,
          reason:    "Special event",
          closed:    "0",
          opens_at:  "10:00",
          closes_at: "15:00"
        }
      }
      expect(response).to redirect_to(edit_staff_store_hours_path)
      exc = StoreException.last
      expect(exc.closed).to be false
      expect(exc.opens_at.strftime("%H:%M")).to eq("10:00")
    end

    it "re-renders edit when invalid (missing reason)" do
      post staff_store_exceptions_path, params: {
        store_exception: { date: Date.current + 7, reason: "", closed: "1" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "redirects to login when unauthenticated" do
      delete logout_path
      post staff_store_exceptions_path, params: {
        store_exception: { date: Date.current + 7, reason: "Test", closed: "1" }
      }
      expect(response).to redirect_to(login_path)
    end
  end

  describe "DELETE /staff/store_exceptions/:id" do
    let!(:exception) do
      StoreException.create!(date: Date.current + 5, reason: "Vacation", closed: true)
    end

    it "destroys the exception and redirects to edit store hours" do
      delete staff_store_exception_path(exception)
      expect(response).to redirect_to(edit_staff_store_hours_path)
      expect(StoreException.exists?(exception.id)).to be false
    end

    it "redirects to login when unauthenticated" do
      delete logout_path
      delete staff_store_exception_path(exception)
      expect(response).to redirect_to(login_path)
    end
  end
end
