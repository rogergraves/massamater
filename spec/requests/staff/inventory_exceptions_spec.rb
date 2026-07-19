require "rails_helper"

RSpec.describe "Staff::InventoryExceptions", type: :request do
  let(:staff)   { create(:user, :staff, phone: "+351910000099") }
  let(:product) { create(:product, name: "Baguette", default_daily_batch_size: 20, default_ready_time: "09:00") }

  before do
    post login_path, params: { phone: staff.phone, password: "password" }
  end

  describe "POST /staff/inventory_exceptions" do
    it "creates a skip exception and redirects" do
      expect {
        post staff_inventory_exceptions_path, params: {
          product_exception: {
            date: Date.tomorrow.to_s,
            product_id: product.id.to_s,
            exception_type: "skip"
          }
        }
      }.to change(ProductException, :count).by(1)

      exc = ProductException.last
      expect(exc.skipped).to be(true)
      expect(exc.batch_size).to be_nil
      expect(response).to redirect_to(staff_inventory_index_path)
    end

    it "creates an override exception with qty and ready time" do
      post staff_inventory_exceptions_path, params: {
        product_exception: {
          date:           Date.tomorrow.to_s,
          product_id:     product.id.to_s,
          exception_type: "override",
          batch_size:     "35",
          ready_time_override: "10:30"
        }
      }

      exc = ProductException.last
      expect(exc.skipped).to be(false)
      expect(exc.added).to be(false)
      expect(exc.batch_size).to eq(35)
      expect(exc.ready_time_override.strftime("%H:%M")).to eq("10:30")
      expect(response).to redirect_to(staff_inventory_index_path)
    end

    it "creates an override exception with qty only (no ready time)" do
      post staff_inventory_exceptions_path, params: {
        product_exception: {
          date:           Date.tomorrow.to_s,
          product_id:     product.id.to_s,
          exception_type: "override",
          batch_size:     "40",
          ready_time_override: ""
        }
      }

      exc = ProductException.last
      expect(exc.batch_size).to eq(40)
      expect(exc.ready_time_override).to be_nil
    end

    it "creates an add exception" do
      post staff_inventory_exceptions_path, params: {
        product_exception: {
          date:           Date.tomorrow.to_s,
          product_id:     product.id.to_s,
          exception_type: "add",
          batch_size:     "8"
        }
      }

      exc = ProductException.last
      expect(exc.added).to be(true)
      expect(exc.batch_size).to eq(8)
      expect(exc.ready_time_override).to be_nil
    end

    it "returns 422 and re-renders when product_id is blank" do
      post staff_inventory_exceptions_path, params: {
        product_exception: {
          date:           Date.tomorrow.to_s,
          product_id:     "",
          exception_type: "skip"
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 when add exception has no batch_size" do
      post staff_inventory_exceptions_path, params: {
        product_exception: {
          date:           Date.tomorrow.to_s,
          product_id:     product.id.to_s,
          exception_type: "add",
          batch_size:     ""
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /staff/inventory_exceptions/:id" do
    let!(:exc) { create(:product_exception, :skip, product: product, date: Date.tomorrow) }

    it "destroys the exception and redirects" do
      expect { delete staff_inventory_exception_path(exc) }.to change(ProductException, :count).by(-1)
      expect(response).to redirect_to(staff_inventory_index_path)
    end
  end

  describe "authentication" do
    it "redirects to login when not authenticated" do
      delete logout_path
      post staff_inventory_exceptions_path, params: {}
      expect(response).to redirect_to(login_path)
    end
  end
end
