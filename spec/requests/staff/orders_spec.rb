require "rails_helper"

RSpec.describe "Staff::Orders", type: :request do
  let(:staff) { create(:user, :staff, phone: "+351910000099") }

  before do
    post login_path, params: { phone: staff.phone, password: "password" }
  end

  describe "GET /staff/orders/new" do
    it "returns 200" do
      get new_staff_order_path
      expect(response).to have_http_status(:ok)
    end

    it "redirects when not authenticated" do
      delete logout_path
      get new_staff_order_path
      expect(response).to redirect_to(login_path)
    end
  end

  describe "GET /staff/orders/products" do
    let!(:product) do
      p = Product.create!(
        name: "Baguette", name_en: "Baguette",
        default_ready_time: "09:00", default_daily_batch_size: 10,
        active: true, order: 1
      )
      p.product_schedule_days.create!(day_of_week: Date.tomorrow.wday)
      p
    end

    it "returns 200 with product rows for a valid date" do
      get products_staff_orders_path, params: { date: Date.tomorrow.iso8601 }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Baguette")
    end

    it "returns 400 for a missing date" do
      get products_staff_orders_path
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "POST /staff/orders" do
    let!(:product) do
      p = Product.create!(
        name: "Baguette", name_en: "Baguette",
        default_ready_time: "09:00", default_daily_batch_size: 10,
        active: true, order: 1
      )
      p.product_schedule_days.create!(day_of_week: Date.tomorrow.wday)
      p
    end

    def valid_params(overrides = {})
      {
        reservation: {
          phone:    "+351920000001",
          name:     "Maria",
          date:     Date.tomorrow.iso8601,
          source:   "phone",
          pickup_time: "",
          note:     "",
          items:    { product.id.to_s => "2" }
        }.merge(overrides)
      }
    end

    it "creates reservation and items for a new customer" do
      expect {
        post staff_orders_path, params: valid_params
      }.to change(Reservation, :count).by(1)
        .and change(ReservationItem, :count).by(1)
        .and change(User, :count).by(1)

      expect(response).to redirect_to(staff_root_path)
    end

    it "reuses an existing customer" do
      User.create!(phone: "+351920000001", name: "Maria")
      expect {
        post staff_orders_path, params: valid_params
      }.to change(User, :count).by(0)
        .and change(Reservation, :count).by(1)
    end

    it "creates the user with nil name when name is blank" do
      post staff_orders_path, params: valid_params(name: "")
      user = User.find_by(phone: "+351920000001")
      expect(user.name).to be_nil
    end

    it "skips items with quantity 0" do
      post staff_orders_path, params: valid_params(items: { product.id.to_s => "0" })
      expect(ReservationItem.count).to eq(0)
    end

    it "stores note and pickup_time when provided" do
      post staff_orders_path, params: valid_params(
        note: "Sliced please",
        pickup_time: "10:30"
      )
      res = Reservation.last
      expect(res.note).to eq("Sliced please")
      expect(res.pickup_time.strftime("%H:%M")).to eq("10:30")
    end

    it "returns 422 when phone is blank" do
      post staff_orders_path, params: valid_params(phone: "")
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
