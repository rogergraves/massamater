require "rails_helper"

RSpec.describe "Staff::Inventory (products)", type: :request do
  let(:staff) { create(:user, :staff, phone: "+351910000099") }

  before do
    post login_path, params: { phone: staff.phone, password: "password" }
  end

  describe "GET /staff/inventory" do
    it "returns 200" do
      get staff_inventory_index_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /staff/inventory" do
    it "creates a product and redirects" do
      expect {
        post staff_inventory_index_path, params: {
          product: {
            name: "Croissant", name_en: "Croissant",
            default_ready_time: "08:00",
            default_daily_batch_size: 10,
            active: true, order: 99
          },
          day_of_week: ["2", "3"]
        }
      }.to change(Product, :count).by(1)

      expect(response).to redirect_to(staff_inventory_index_path)
    end

    it "returns 422 when name is blank" do
      post staff_inventory_index_path, params: {
        product: {
          name: "", default_ready_time: "08:00",
          default_daily_batch_size: 10, active: true, order: 1
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /staff/inventory/:id" do
    let!(:product) do
      Product.create!(
        name: "Bolacha", name_en: "Cookie",
        default_ready_time: "09:00", default_daily_batch_size: 12,
        active: true, order: 1
      )
    end

    it "updates the product and redirects" do
      patch staff_inventory_path(product), params: {
        product: { name: "Bolacha Especial", name_en: "Special Cookie",
                   default_ready_time: "09:00", default_daily_batch_size: 12,
                   active: true, order: 1 },
        day_of_week: ["5"]
      }
      expect(response).to redirect_to(staff_inventory_index_path)
      expect(product.reload.name).to eq("Bolacha Especial")
    end

    it "returns 422 when name is blank" do
      patch staff_inventory_path(product), params: {
        product: { name: "", default_ready_time: "09:00",
                   default_daily_batch_size: 12, active: true, order: 1 }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /staff/inventory/:id" do
    let!(:product) do
      Product.create!(
        name: "Temporary", name_en: "Temporary",
        default_ready_time: "08:00", default_daily_batch_size: 5,
        active: true, order: 99
      )
    end

    it "destroys the product and redirects" do
      expect { delete staff_inventory_path(product) }.to change(Product, :count).by(-1)
      expect(response).to redirect_to(staff_inventory_index_path)
    end
  end

  describe "authentication" do
    it "redirects to login when not authenticated" do
      delete logout_path
      get staff_inventory_index_path
      expect(response).to redirect_to(login_path)
    end
  end
end
