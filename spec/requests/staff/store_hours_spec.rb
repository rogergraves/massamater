require "rails_helper"

RSpec.describe "Staff::StoreHours", type: :request do
  let(:staff) { create(:user, :staff, phone: "+351910000099") }

  before do
    post login_path, params: { phone: staff.phone, password: "password" }
    %i[sunday monday tuesday wednesday thursday friday saturday].each_with_index do |day, i|
      StoreHour.find_or_create_by!(day_of_week: i) do |sh|
        sh.open      = day.in?(%i[tuesday wednesday thursday friday saturday])
        sh.opens_at  = "08:00"
        sh.closes_at = "18:00"
      end
    end
  end

  describe "GET /staff/store_hours/edit" do
    it "returns 200 and all 7 day rows" do
      get edit_staff_store_hours_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Monday", "Tuesday", "Wednesday",
                                       "Thursday", "Friday", "Saturday", "Sunday")
    end
  end

  describe "PATCH /staff/store_hours" do
    it "updates open/closed and times for each day" do
      tuesday = StoreHour.find_by!(day_of_week: :tuesday)
      patch staff_store_hours_path, params: {
        store_hours: {
          tuesday.id.to_s => { open: "1", opens_at: "09:00", closes_at: "17:00" }
        }
      }
      expect(response).to redirect_to(edit_staff_store_hours_path)
      tuesday.reload
      expect(tuesday.open).to be true
      expect(tuesday.opens_at.strftime("%H:%M")).to eq("09:00")
      expect(tuesday.closes_at.strftime("%H:%M")).to eq("17:00")
    end

    it "sets a day as closed when open param is missing" do
      tuesday = StoreHour.find_by!(day_of_week: :tuesday)
      patch staff_store_hours_path, params: {
        store_hours: {
          tuesday.id.to_s => { opens_at: "09:00", closes_at: "17:00" }
        }
      }
      tuesday.reload
      expect(tuesday.open).to be false
    end

    it "redirects to login when not authenticated" do
      delete logout_path
      patch staff_store_hours_path, params: { store_hours: {} }
      expect(response).to redirect_to(login_path)
    end
  end
end
