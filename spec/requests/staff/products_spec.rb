# spec/requests/staff/products_spec.rb
require "rails_helper"

RSpec.describe "Staff::Products", type: :request do
  let(:staff) { create(:user, :staff, phone: "+351910000099") }

  before do
    post login_path, params: { phone: staff.phone, password: "password" }
  end

  describe "GET /staff/products" do
    it "returns 200 and shows products heading" do
      get staff_products_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("catalog")
    end
  end

  describe "POST /staff/products" do
    it "creates a product and redirects" do
      expect {
        post staff_products_path, params: {
          product: {
            name: "Croissant", name_en: "Croissant",
            default_ready_time: "08:00",
            default_daily_batch_size: 10,
            active: true, order: 99
          },
          day_of_week: ["2", "3"]
        }
      }.to change(Product, :count).by(1)

      expect(response).to redirect_to(staff_products_path)
      follow_redirect!
      expect(response.body).to include("Croissant")
    end

    it "returns 422 when name is blank" do
      post staff_products_path, params: {
        product: {
          name: "", default_ready_time: "08:00",
          default_daily_batch_size: 10, active: true, order: 1
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /staff/products/:id" do
    let!(:product) do
      Product.create!(
        name: "Bolacha", name_en: "Cookie",
        default_ready_time: "09:00", default_daily_batch_size: 12,
        active: true, order: 1
      )
    end

    it "updates the product and redirects" do
      patch staff_product_path(product), params: {
        product: { name: "Bolacha Especial", name_en: "Special Cookie",
                   default_ready_time: "09:00", default_daily_batch_size: 12,
                   active: true, order: 1 },
        day_of_week: ["5"]
      }
      expect(response).to redirect_to(staff_products_path)
      expect(product.reload.name).to eq("Bolacha Especial")
      expect(product.product_schedule_days.pluck(:day_of_week)).to eq(["friday"])
    end

    it "returns 422 when name is blank" do
      patch staff_product_path(product), params: {
        product: { name: "", default_ready_time: "09:00",
                   default_daily_batch_size: 12, active: true, order: 1 }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /staff/products/:id" do
    let!(:product) do
      Product.create!(
        name: "Temporary", name_en: "Temporary",
        default_ready_time: "08:00", default_daily_batch_size: 5,
        active: true, order: 99
      )
    end

    it "destroys the product and redirects" do
      expect { delete staff_product_path(product) }.to change(Product, :count).by(-1)
      expect(response).to redirect_to(staff_products_path)
    end
  end

  describe "authentication" do
    it "redirects to login when not authenticated" do
      delete logout_path
      get staff_products_path
      expect(response).to redirect_to(login_path)
    end
  end
end
