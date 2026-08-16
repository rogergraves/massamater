# Inventory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge the Product Catalog and a new Exceptions system into a single "Inventory" page — the products section is the standing defaults, and an exceptions section (identical in UX to store hours exceptions) lets staff override products on specific dates.

**Architecture:** Replace `Staff::ProductsController` with `Staff::InventoryController` (same product CRUD, new URL `/staff/inventory`). Add `Staff::InventoryExceptionsController` for creating/destroying `ProductException` records. The combined view follows the Store Hours two-section pattern: products at top with per-row inline save, exceptions at bottom with an always-visible add form and × delete buttons. A new `inventory-exception-form` Stimulus controller shows/hides qty and time fields based on the selected exception type radio.

**Tech Stack:** Rails 8.1.3, Ruby 4.0.1, RSpec, FactoryBot, Stimulus (Hotwire), SQLite3

---

## Files

**Create:**
- `app/controllers/staff/inventory_controller.rb`
- `app/controllers/staff/inventory_exceptions_controller.rb`
- `app/views/staff/inventory/index.html.erb`
- `app/views/staff/inventory/_product_form.html.erb`
- `app/javascript/controllers/inventory_exception_form_controller.js`
- `spec/requests/staff/inventory_spec.rb`
- `spec/requests/staff/inventory_exceptions_spec.rb`
- `db/migrate/TIMESTAMP_rename_daily_inventories_to_product_exceptions.rb`
- `app/models/product_exception.rb`
- `spec/factories/product_exceptions.rb`

**Modify:**
- `config/routes.rb`
- `app/views/layouts/staff.html.erb`
- `config/locales/en.yml`
- `config/locales/pt.yml`
- `app/assets/stylesheets/application.css`

**Delete:**
- `app/models/daily_inventory.rb`
- `spec/factories/daily_inventories.rb`

**Delete** (after new files work):
- `app/controllers/staff/products_controller.rb`
- `app/views/staff/products/index.html.erb`
- `app/views/staff/products/_product_form.html.erb`
- `spec/requests/staff/products_spec.rb`

---

## Task 1: Migration — rename table and make `batch_size` nullable

**Files:**
- Create: `db/migrate/TIMESTAMP_rename_daily_inventories_to_product_exceptions.rb`
- Modify: `db/schema.rb` (auto-updated by Rails)

### Context

Two changes in one migration:
1. Rename `daily_inventories` → `product_exceptions` to match the UI and mirror `store_exceptions`.
2. Make `batch_size` nullable — Skip exceptions have no quantity, and Override exceptions may override only the ready time (leaving batch_size null).

- [ ] **Step 1: Generate the migration**

```bash
bin/rails generate migration RenameDailyInventoriesToProductExceptions
```

- [ ] **Step 2: Write the migration body**

Open the generated file in `db/migrate/` and replace its body with:

```ruby
class RenameDailyInventoriesToProductExceptions < ActiveRecord::Migration[8.1]
  def change
    rename_table :daily_inventories, :product_exceptions
    change_column_null :product_exceptions, :batch_size, true
    change_column_default :product_exceptions, :batch_size, nil
  end
end
```

- [ ] **Step 3: Run the migration**

```bash
bin/rails db:migrate
```

Expected: `== RenameDailyInventoriesToProductExceptions: migrating`… no errors.

- [ ] **Step 4: Verify schema**

```bash
grep -A 12 'create_table "product_exceptions"' db/schema.rb
```

Expected: table named `product_exceptions` with `t.integer "batch_size"` (no `null: false`).

- [ ] **Step 5: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "feat: rename daily_inventories to product_exceptions, make batch_size nullable"
```

---

## Task 2: Create `ProductException` model, replace `DailyInventory`

**Files:**
- Create: `app/models/product_exception.rb`
- Create: `spec/factories/product_exceptions.rb`
- Delete: `app/models/daily_inventory.rb`
- Delete: `spec/factories/daily_inventories.rb`

### Context

The table is now `product_exceptions`. The model class becomes `ProductException`. It needs updated validations (batch_size nullable) and an `exception_summary` method for display in the exceptions list. The old `DailyInventory` model file and factory are deleted.

- [ ] **Step 1: Create `app/models/product_exception.rb`**

```ruby
class ProductException < ApplicationRecord
  belongs_to :product

  validates :date,       presence: true, uniqueness: { scope: :product_id }
  validates :batch_size, numericality: { only_integer: true, greater_than_or_equal_to: 1 },
                         allow_nil: true
  validates :batch_size, presence: true, if: :added?

  def effective_ready_time
    ready_time_override || product.default_ready_time
  end

  def exception_summary
    if skipped?
      I18n.t("staff.inventory.exceptions.type_skip")
    else
      parts = []
      parts << I18n.t("staff.inventory.exceptions.qty_summary", qty: batch_size) if batch_size.present?
      parts << ready_time_override.strftime("%H:%M") if ready_time_override.present?
      prefix = added? ? "#{I18n.t('staff.inventory.exceptions.type_add')} — " : ""
      "#{prefix}#{parts.join(', ')}"
    end
  end
end
```

- [ ] **Step 2: Update `app/models/product.rb` association**

Open `app/models/product.rb`. Find the `has_many :daily_inventories` line and change it to:

```ruby
has_many :product_exceptions, dependent: :destroy
```

- [ ] **Step 3: Create `spec/factories/product_exceptions.rb`**

```ruby
FactoryBot.define do
  factory :product_exception do
    product
    date                { Date.today }
    batch_size          { 12 }
    ready_time_override { nil }
    skipped             { false }
    added               { false }

    trait :skip do
      skipped    { true }
      batch_size { nil }
    end

    trait :override do
      batch_size { 20 }
    end

    trait :added do
      added      { true }
      batch_size { 8 }
    end
  end
end
```

- [ ] **Step 4: Delete the old model and factory**

```bash
git rm app/models/daily_inventory.rb
git rm spec/factories/daily_inventories.rb
```

- [ ] **Step 5: Run existing model specs to verify nothing is broken**

```bash
bin/rspec spec/models/ --format documentation 2>&1 | tail -10
```

Expected: any existing model specs pass (or no model specs exist yet, which is fine).

- [ ] **Step 6: Commit**

```bash
git add app/models/product_exception.rb app/models/product.rb spec/factories/product_exceptions.rb
git commit -m "feat: introduce ProductException model, replace DailyInventory"
```

---

## Task 3: Routes, nav, and i18n

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/views/layouts/staff.html.erb`
- Modify: `config/locales/en.yml`
- Modify: `config/locales/pt.yml`

### Context

`resources :inventory` inside `namespace :staff` generates:
- `staff_inventory_index_path` — GET /staff/inventory (index)
- `staff_inventory_path(product)` — PATCH/DELETE /staff/inventory/:id
- `staff_inventory_exceptions_path` — POST /staff/inventory_exceptions
- `staff_inventory_exception_path(exc)` — DELETE /staff/inventory_exceptions/:id

The nav currently has two links: "Inventory" (pointing to `#`) and "Products" (pointing to `staff_products_path`). After this task, "Inventory" points to the new path and "Products" is removed.

- [ ] **Step 1: Update `config/routes.rb`**

```ruby
Rails.application.routes.draw do
  root "pages#home"

  get    "/login",  to: "sessions#new",     as: :login
  post   "/login",  to: "sessions#create"
  delete "/logout", to: "sessions#destroy", as: :logout

  patch "/locale", to: "locales#update", as: :locale

  namespace :staff do
    root "dashboard#index"
    resources :inventory,            only: [:index, :create, :update, :destroy]
    resources :inventory_exceptions, only: [:create, :destroy]
    resource  :store_hours,          only: [:edit, :update]
    resources :store_exceptions,     only: [:create, :destroy]
  end
end
```

- [ ] **Step 2: Update the nav in `app/views/layouts/staff.html.erb`**

Find the two nav links for inventory and products. Replace both with a single inventory link:

```erb
<%= link_to t("staff.nav.inventory"), staff_inventory_index_path, class: "nav-link" %>
```

The full `staff-nav-links` div becomes:

```erb
<div class="staff-nav-links">
  <%= link_to t("staff.nav.today"),    staff_root_path,               class: "nav-link" %>
  <%= link_to t("staff.nav.inventory"), staff_inventory_index_path,   class: "nav-link" %>
  <%= link_to t("staff.nav.settings"), edit_staff_store_hours_path,   class: "nav-link" %>
</div>
```

- [ ] **Step 3: Update `config/locales/en.yml`**

Replace the entire `staff.products:` block with `staff.inventory:`. Remove `staff.nav.products`. The relevant section of `en.yml` becomes:

```yaml
  staff:
    nav:
      today: "Today"
      inventory: "Inventory"
      settings: "Hours"
    dashboard:
      placeholder: "Dashboard"
    inventory:
      title: "Inventory"
      subtitle: "Products and date-specific exceptions"
      new_btn: "+ New product"
      new_title: "New product"
      name_label: "Name (PT)"
      name_en_label: "Name (EN)"
      ready_time_label: "Default ready time"
      batch_size_label: "Default batch size"
      max_per_client_label: "Max per customer"
      max_per_client_hint: "Leave blank = no limit"
      active_label: "Active"
      schedule_label: "Available days"
      photo_label: "Photo"
      order_label: "Order"
      inactive_badge: "(inactive)"
      save_btn: "Save"
      cancel_btn: "Cancel"
      add_btn: "Add"
      created: "Product created."
      saved: "Product saved."
      deleted: "Product deleted."
      products_title: "Products"
      products_subtitle: "Default offerings — what you normally sell each day"
      exceptions_title: "Exceptions"
      exceptions_subtitle: "Override products on specific dates"
      exceptions:
        add_placeholder_date: "Date"
        add_placeholder_product: "Product"
        type_skip: "Skip"
        type_override: "Override"
        type_add: "Add"
        qty_label: "Qty"
        ready_time_label: "Ready at"
        add_button: "+ Add"
        added: "Exception added."
        removed: "Exception removed."
        qty_summary: "Qty: %{qty}"
```

- [ ] **Step 4: Update `config/locales/pt.yml`**

Replace `staff.products:` with `staff.inventory:`. Remove `staff.nav.products`. The relevant section becomes:

```yaml
  staff:
    nav:
      today: "Hoje"
      inventory: "Inventário"
      settings: "Horário da Loja"
    dashboard:
      placeholder: "Painel de controlo"
    inventory:
      title: "Inventário"
      subtitle: "Produtos e exceções por data"
      new_btn: "+ Novo produto"
      new_title: "Novo produto"
      name_label: "Nome (PT)"
      name_en_label: "Nome (EN)"
      ready_time_label: "Hora de saída padrão"
      batch_size_label: "Lote diário padrão"
      max_per_client_label: "Máx. por cliente"
      max_per_client_hint: "Deixar em branco = sem limite"
      active_label: "Activo"
      schedule_label: "Dias disponíveis"
      photo_label: "Foto"
      order_label: "Ordem"
      inactive_badge: "(inactivo)"
      save_btn: "Guardar"
      cancel_btn: "Cancelar"
      add_btn: "Adicionar"
      created: "Produto criado."
      saved: "Produto guardado."
      deleted: "Produto eliminado."
      products_title: "Produtos"
      products_subtitle: "Oferta padrão — o que vendes normalmente cada dia"
      exceptions_title: "Exceções"
      exceptions_subtitle: "Substituir produtos em datas específicas"
      exceptions:
        add_placeholder_date: "Data"
        add_placeholder_product: "Produto"
        type_skip: "Não vender"
        type_override: "Substituir"
        type_add: "Adicionar"
        qty_label: "Qtd"
        ready_time_label: "Pronto às"
        add_button: "+ Adicionar"
        added: "Exceção adicionada."
        removed: "Exceção removida."
        qty_summary: "Qtd: %{qty}"
```

- [ ] **Step 5: Verify routes exist**

```bash
bin/rails routes | grep inventory
```

Expected lines include:
```
staff_inventory_index  GET    /staff/inventory(.:format)               staff/inventory#index
                       POST   /staff/inventory(.:format)               staff/inventory#create
       staff_inventory GET    /staff/inventory/:id(.:format)           staff/inventory#show
                       PATCH  /staff/inventory/:id(.:format)           staff/inventory#update
                       DELETE /staff/inventory/:id(.:format)           staff/inventory#destroy
staff_inventory_exceptions POST   /staff/inventory_exceptions(.:format)  staff/inventory_exceptions#create
 staff_inventory_exception DELETE /staff/inventory_exceptions/:id(.:format) staff/inventory_exceptions#destroy
```

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/views/layouts/staff.html.erb config/locales/en.yml config/locales/pt.yml
git commit -m "feat: inventory routes, nav, and i18n — replace products"
```

---

## Task 4: `Staff::InventoryController` + request spec

**Files:**
- Create: `app/controllers/staff/inventory_controller.rb`
- Create: `spec/requests/staff/inventory_spec.rb`

### Context

This controller is a rename of `Staff::ProductsController` with the path changed from `/staff/products` to `/staff/inventory`. All product CRUD behaviour is identical. Redirect targets change to `staff_inventory_index_path`.

- [ ] **Step 1: Write the request spec**

Create `spec/requests/staff/inventory_spec.rb`:

```ruby
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
```

- [ ] **Step 2: Run the spec — expect FAIL (controller not yet written)**

```bash
bin/rspec spec/requests/staff/inventory_spec.rb 2>&1 | head -20
```

Expected: failures because `Staff::InventoryController` doesn't exist.

- [ ] **Step 3: Create `app/controllers/staff/inventory_controller.rb`**

```ruby
class Staff::InventoryController < Staff::BaseController
  before_action :set_product, only: [:update, :destroy]

  def index
    load_index_data
  end

  def create
    @product = Product.new(product_params)
    ApplicationRecord.transaction do
      @product.save!
      save_schedule(@product)
    end
    redirect_to staff_inventory_index_path, notice: t("staff.inventory.created")
  rescue ActiveRecord::RecordInvalid
    load_index_data
    @new_product    = @product
    @show_new_form  = true
    render :index, status: :unprocessable_entity
  end

  def update
    ApplicationRecord.transaction do
      @product.update!(product_params)
      save_schedule(@product)
    end
    redirect_to staff_inventory_index_path, notice: t("staff.inventory.saved")
  rescue ActiveRecord::RecordInvalid
    load_index_data
    @editing_product_id = @product.id
    render :index, status: :unprocessable_entity
  end

  def destroy
    @product.destroy
    redirect_to staff_inventory_index_path, notice: t("staff.inventory.deleted")
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def load_index_data
    @products    = Product.ordered.with_attached_photo.includes(:product_schedule_days)
    @open_days   = StoreHour.where(open: true).pluck(:day_of_week).map { |d| StoreHour.day_of_weeks[d] }
    @new_product = Product.new(default_ready_time: "09:00:00")
    @exceptions  = ProductException.where("date >= ?", Date.current)
                                   .order(:date)
                                   .includes(:product)
    @new_exception = ProductException.new(date: Date.current)
  end

  def product_params
    params.require(:product).permit(
      :name, :name_en, :default_ready_time, :default_daily_batch_size,
      :max_reservable_quantity_per_client, :active, :order, :photo
    )
  end

  def save_schedule(product)
    selected = (params[:day_of_week] || []).map(&:to_i)
    product.product_schedule_days.where.not(day_of_week: selected).destroy_all
    selected.each { |day| product.product_schedule_days.find_or_create_by!(day_of_week: day) }
  end
end
```

- [ ] **Step 4: The view doesn't exist yet — create a minimal stub so the spec can render**

```bash
mkdir -p app/views/staff/inventory
```

Create `app/views/staff/inventory/index.html.erb` with just:

```erb
<div class="wrap"><p>Inventory</p></div>
```

(This will be replaced in Task 6.)

- [ ] **Step 5: Run the spec — expect PASS**

```bash
bin/rspec spec/requests/staff/inventory_spec.rb
```

Expected: 7 examples, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/staff/inventory_controller.rb spec/requests/staff/inventory_spec.rb app/views/staff/inventory/index.html.erb
git commit -m "feat: add Staff::InventoryController with request spec"
```

---

## Task 5: `Staff::InventoryExceptionsController` + request spec

**Files:**
- Create: `app/controllers/staff/inventory_exceptions_controller.rb`
- Create: `spec/requests/staff/inventory_exceptions_spec.rb`

### Context

The exception form submits a `product_exception[exception_type]` radio value (`"skip"`, `"override"`, or `"add"`) alongside `product_exception[date]`, `product_exception[product_id]`, `product_exception[batch_size]`, and `product_exception[ready_time_override]`. The controller derives `skipped` and `added` from `exception_type` and merges them in, stripping fields that don't apply to each type.

- [ ] **Step 1: Write the request spec**

Create `spec/requests/staff/inventory_exceptions_spec.rb`:

```ruby
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
```

- [ ] **Step 2: Run the spec — expect FAIL**

```bash
bin/rspec spec/requests/staff/inventory_exceptions_spec.rb 2>&1 | head -20
```

Expected: failures because the controller doesn't exist.

- [ ] **Step 3: Create `app/controllers/staff/inventory_exceptions_controller.rb`**

```ruby
class Staff::InventoryExceptionsController < Staff::BaseController
  def create
    @exception = ProductException.new(build_exception_attrs)
    if @exception.save
      redirect_to staff_inventory_index_path, notice: t("staff.inventory.exceptions.added")
    else
      load_index_data
      @new_exception = @exception
      render "staff/inventory/index", status: :unprocessable_entity
    end
  end

  def destroy
    ProductException.find(params[:id]).destroy
    redirect_to staff_inventory_index_path, notice: t("staff.inventory.exceptions.removed")
  end

  private

  def build_exception_attrs
    type       = params.dig(:product_exception, :exception_type)
    date       = params.dig(:product_exception, :date)
    product_id = params.dig(:product_exception, :product_id)
    batch_size = params.dig(:product_exception, :batch_size).presence
    ready_time = params.dig(:product_exception, :ready_time_override).presence

    case type
    when "skip"
      { product_id: product_id, date: date,
        skipped: true, added: false, batch_size: nil, ready_time_override: nil }
    when "override"
      { product_id: product_id, date: date,
        skipped: false, added: false,
        batch_size: batch_size,
        ready_time_override: ready_time }
    when "add"
      { product_id: product_id, date: date,
        skipped: false, added: true,
        batch_size: batch_size,
        ready_time_override: nil }
    else
      { product_id: product_id, date: date }
    end
  end

  def load_index_data
    @products      = Product.ordered.with_attached_photo.includes(:product_schedule_days)
    @open_days     = StoreHour.where(open: true).pluck(:day_of_week).map { |d| StoreHour.day_of_weeks[d] }
    @new_product   = Product.new(default_ready_time: "09:00:00")
    @exceptions    = ProductException.where("date >= ?", Date.current)
                                     .order(:date)
                                     .includes(:product)
    @new_exception = @exception
  end
end
```

- [ ] **Step 4: Run the spec — expect PASS**

```bash
bin/rspec spec/requests/staff/inventory_exceptions_spec.rb
```

Expected: 8 examples, 0 failures. If any fail, read the error carefully — the most likely issue is a validation on `ProductException` rejecting nil batch_size (fix: ensure Task 1's migration ran and Task 2's model changes are applied).

- [ ] **Step 5: Run both new specs together**

```bash
bin/rspec spec/requests/staff/inventory_spec.rb spec/requests/staff/inventory_exceptions_spec.rb
```

Expected: 15 examples, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/staff/inventory_exceptions_controller.rb spec/requests/staff/inventory_exceptions_spec.rb
git commit -m "feat: add Staff::InventoryExceptionsController with request spec"
```

---

## Task 6: Inventory view

**Files:**
- Modify (replace stub): `app/views/staff/inventory/index.html.erb`
- Create: `app/views/staff/inventory/_product_form.html.erb`

### Context

The view has two sections separated visually as section-cards:

1. **Products** — identical to the current `app/views/staff/products/index.html.erb` except path helpers change from `staff_products_path` → `staff_inventory_index_path` and `staff_product_path` → `staff_inventory_path`. The `product-catalog` Stimulus controller is unchanged and reused.

2. **Exceptions** — follows the store hours exceptions pattern exactly: an existing exceptions list (each row with date, product name, summary label, × button), followed by an always-visible add form with date, product select, type radios, and conditional qty/time fields.

The add form uses `data-controller="inventory-exception-form"` (built in Task 7). Until Task 7 is done, the fields always show — that's fine, the form still works.

- [ ] **Step 1: Create the product form partial**

Create `app/views/staff/inventory/_product_form.html.erb`. This is identical to the existing `app/views/staff/products/_product_form.html.erb` (copy it exactly — we will delete the products version in Task 9):

```erb
<%# app/views/staff/inventory/_product_form.html.erb %>
<div class="prod-detail">
  <% if show_errors && product.errors.any? %>
    <div class="form-errors"><%= product.errors.full_messages.to_sentence %></div>
  <% end %>

  <div class="detail-row">
    <div class="detail-field">
      <%= f.label :name, t("staff.inventory.name_label"), class: "detail-label" %>
      <%= f.text_field :name, class: "name-in" %>
    </div>
    <div class="detail-field">
      <%= f.label :name_en, t("staff.inventory.name_en_label"), class: "detail-label" %>
      <%= f.text_field :name_en, class: "name-in" %>
    </div>
  </div>

  <div class="detail-label mt-14"><%= t("staff.inventory.schedule_label") %></div>
  <div class="day-grid">
    <% (0..6).each do |day_num| %>
      <% closed   = !open_days.include?(day_num) %>
      <% selected = product.product_schedule_days.any? { |d| d.day_of_week_before_type_cast == day_num } %>
      <div class="day-toggle">
        <div class="day-label"><%= I18n.t("date.day_names")[day_num].first(3) %></div>
        <label class="day-box <%= 'checked' if selected %> <%= 'closed-day' if closed %>">
          <%= check_box_tag "day_of_week[]", day_num, selected,
                            disabled: closed,
                            class: "sr-only",
                            data: { action: "change->product-catalog#toggleDayBox" } %>
          <%= I18n.t("date.day_names")[day_num].first %>
        </label>
      </div>
    <% end %>
  </div>

  <div class="detail-row mt-14">
    <div class="detail-field">
      <%= f.label :default_ready_time, t("staff.inventory.ready_time_label"), class: "detail-label" %>
      <%= f.time_field :default_ready_time, class: "time-in" %>
    </div>
    <div class="detail-field">
      <%= f.label :default_daily_batch_size, t("staff.inventory.batch_size_label"), class: "detail-label" %>
      <%= f.number_field :default_daily_batch_size, min: 1, class: "num-in" %>
    </div>
    <div class="detail-field">
      <%= f.label :max_reservable_quantity_per_client, t("staff.inventory.max_per_client_label"), class: "detail-label" %>
      <%= f.number_field :max_reservable_quantity_per_client, min: 1, placeholder: "∞", class: "num-in" %>
    </div>
    <div class="detail-field">
      <%= f.label :order, t("staff.inventory.order_label"), class: "detail-label" %>
      <%= f.number_field :order, min: 0, class: "num-in" %>
    </div>
    <div class="detail-field">
      <div class="detail-label"><%= t("staff.inventory.active_label") %></div>
      <label class="toggle <%= 'off' unless product.active? %>">
        <%= f.check_box :active, class: "sr-only",
                        data: { action: "change->product-catalog#toggleActive" } %>
        <div class="knob"></div>
      </label>
    </div>
    <div class="detail-field">
      <%= f.label :photo, t("staff.inventory.photo_label"), class: "detail-label" %>
      <%= f.file_field :photo, accept: "image/*", class: "photo-in" %>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Replace the stub with the full view**

Replace `app/views/staff/inventory/index.html.erb` entirely:

```erb
<%# app/views/staff/inventory/index.html.erb %>
<div class="wrap"
     data-controller="product-catalog"
     data-product-catalog-open-id-value="<%= @editing_product_id %>">

  <div class="topbar">
    <div>
      <div class="pg-title"><%= t("staff.inventory.title") %></div>
      <div class="pg-sub"><%= t("staff.inventory.subtitle") %></div>
    </div>
    <button class="add-btn"
            data-action="click->product-catalog#showNew"
            data-product-catalog-target="newBtn">
      <%= t("staff.inventory.new_btn") %>
    </button>
  </div>

  <%# New product form (hidden by default) %>
  <div data-product-catalog-target="newForm"
       style="<%= 'display:none' unless @show_new_form %>"
       class="section-card">
    <div class="section-head">
      <div class="section-head-title"><%= t("staff.inventory.new_title") %></div>
    </div>
    <%= form_with model: @new_product, url: staff_inventory_index_path, multipart: true do |f| %>
      <%= render "product_form", f: f, product: @new_product, open_days: @open_days, show_errors: @show_new_form %>
      <div class="form-actions">
        <%= f.submit t("staff.inventory.add_btn"), class: "save-btn" %>
        <button type="button" class="cancel-btn" data-action="click->product-catalog#hideNew">
          <%= t("staff.inventory.cancel_btn") %>
        </button>
      </div>
    <% end %>
  </div>

  <%# Products section %>
  <div class="section-card">
    <div class="section-head">
      <div class="section-head-title"><%= t("staff.inventory.products_title") %></div>
      <div class="section-head-sub"><%= t("staff.inventory.products_subtitle") %></div>
    </div>

    <div class="prod-list">
      <% @products.each do |product| %>
        <% editing = @editing_product_id == product.id %>
        <div class="prod-row" id="prod-row-<%= product.id %>">

          <div id="product-summary-<%= product.id %>"
               class="prod-main"
               style="<%= 'display:none' if editing %>">

            <%= form_with url: staff_inventory_path(product),
                          method: :patch,
                          multipart: true,
                          class: "photo-upload-form",
                          data: { action: "change->product-catalog#uploadPhoto" } do |f| %>
              <label class="photo-cell <%= 'empty' unless product.photo.attached? %>" title="<%= t('staff.inventory.photo_label') %>">
                <% if product.photo.attached? %>
                  <%= image_tag product.photo, class: "prod-photo" %>
                <% else %>
                  + photo
                <% end %>
                <%= f.file_field :photo, accept: "image/*", class: "sr-only" %>
              </label>
            <% end %>

            <div class="prod-name <%= 'inactive' unless product.active? %>">
              <%= product.display_name %>
              <% unless product.active? %>
                <span class="inactive-badge"><%= t("staff.inventory.inactive_badge") %></span>
              <% end %>
            </div>

            <div class="day-pills">
              <% (0..6).each do |day_num| %>
                <% on = product.product_schedule_days.any? { |d| d.day_of_week_before_type_cast == day_num } %>
                <div class="dp <%= 'on' if on %>" title="<%= I18n.t('date.day_names')[day_num] %>">
                  <%= I18n.t("date.day_names")[day_num].first %>
                </div>
              <% end %>
            </div>

            <div class="row-actions">
              <button class="icon-btn"
                      data-action="click->product-catalog#open"
                      data-product-id="<%= product.id %>">✏</button>
              <%= button_to "×",
                            staff_inventory_path(product),
                            method: :delete,
                            class: "icon-btn danger" %>
            </div>
          </div>

          <div id="product-form-<%= product.id %>"
               style="<%= 'display:none' unless editing %>">
            <%= form_with model: product,
                          url: staff_inventory_path(product),
                          method: :patch,
                          multipart: true do |f| %>
              <%= render "product_form", f: f, product: product, open_days: @open_days, show_errors: editing %>
              <div class="form-actions">
                <%= f.submit t("staff.inventory.save_btn"), class: "save-btn" %>
                <button type="button" class="cancel-btn"
                        data-action="click->product-catalog#close"
                        data-product-id="<%= product.id %>">
                  <%= t("staff.inventory.cancel_btn") %>
                </button>
              </div>
            <% end %>
          </div>

        </div>
      <% end %>
    </div>
  </div>

  <%# Exceptions section %>
  <div class="section-card">
    <div class="section-head">
      <div class="section-head-title"><%= t("staff.inventory.exceptions_title") %></div>
      <div class="section-head-sub"><%= t("staff.inventory.exceptions_subtitle") %></div>
    </div>

    <% @exceptions.each do |exc| %>
      <div class="exc-row">
        <div class="exc-date">
          <% if exc.date == Date.current %>
            Today, <%= exc.date.strftime("%b %-d") %>
          <% else %>
            <%= exc.date.strftime("%b %-d, %a") %>
          <% end %>
        </div>
        <div class="exc-reason"><%= exc.product.display_name %></div>
        <span class="hours-tag"><%= exc.exception_summary %></span>
        <%= button_to "×",
                      staff_inventory_exception_path(exc),
                      method: :delete,
                      class: "del-btn" %>
      </div>
    <% end %>

    <%# Add exception form %>
    <%= form_with model: @new_exception,
                  url: staff_inventory_exceptions_path,
                  data: { controller: "inventory-exception-form",
                          action: "change->inventory-exception-form#typeChanged" } do |f| %>
      <div class="add-exc-row">
        <%= f.date_field :date,
                         value: @new_exception.date || Date.current,
                         min: Date.current,
                         class: "date-in" %>

        <select name="product_exception[product_id]" class="reason-in">
          <option value=""><%= t("staff.inventory.exceptions.add_placeholder_product") %></option>
          <% @products.each do |p| %>
            <option value="<%= p.id %>" <%= "selected" if @new_exception.product_id == p.id %>>
              <%= p.display_name %>
            </option>
          <% end %>
        </select>

        <div class="type-sel">
          <label class="type-opt <%= 'sel' if @new_exception.skipped? || @new_exception.new_record? %>">
            <input type="radio" name="product_exception[exception_type]" value="skip"
                   <%= "checked" if @new_exception.new_record? || @new_exception.skipped? %> />
            <%= t("staff.inventory.exceptions.type_skip") %>
          </label>
          <label class="type-opt <%= 'sel' if !@new_exception.new_record? && !@new_exception.skipped? && !@new_exception.added? %>">
            <input type="radio" name="product_exception[exception_type]" value="override"
                   <%= "checked" if !@new_exception.new_record? && !@new_exception.skipped? && !@new_exception.added? %> />
            <%= t("staff.inventory.exceptions.type_override") %>
          </label>
          <label class="type-opt <%= 'sel' if @new_exception.added? %>">
            <input type="radio" name="product_exception[exception_type]" value="add"
                   <%= "checked" if @new_exception.added? %> />
            <%= t("staff.inventory.exceptions.type_add") %>
          </label>
        </div>

        <div data-inventory-exception-form-target="qtyFields" style="display:none">
          <%= f.label :batch_size, t("staff.inventory.exceptions.qty_label"), class: "detail-label" %>
          <%= f.number_field :batch_size, min: 1, class: "num-in",
                             value: @new_exception.batch_size %>
        </div>

        <div data-inventory-exception-form-target="timeFields" style="display:none">
          <%= f.label :ready_time_override, t("staff.inventory.exceptions.ready_time_label"), class: "detail-label" %>
          <%= f.time_field :ready_time_override, class: "time-in",
                           value: @new_exception.ready_time_override&.strftime("%H:%M") %>
        </div>

        <%= f.submit t("staff.inventory.exceptions.add_button"), class: "add-btn-sm" %>
      </div>

      <% if @new_exception.errors.any? %>
        <div class="form-errors">
          <%= @new_exception.errors.full_messages.to_sentence %>
        </div>
      <% end %>
    <% end %>
  </div>

</div>
```

- [ ] **Step 3: Run all inventory specs to confirm the view renders correctly**

```bash
bin/rspec spec/requests/staff/inventory_spec.rb spec/requests/staff/inventory_exceptions_spec.rb
```

Expected: 15 examples, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add app/views/staff/inventory/
git commit -m "feat: add Inventory view with products section and exceptions section"
```

---

## Task 7: Stimulus controller for exception form

**Files:**
- Create: `app/javascript/controllers/inventory_exception_form_controller.js`

### Context

The exception form has three type radios (skip / override / add). The Stimulus controller shows/hides:
- `qtyFields` target: visible for `override` and `add`
- `timeFields` target: visible for `override` only

This mirrors the `exception_form_controller.js` used on the store hours page. Also updates the `.sel` class on the radio labels (same as the store hours version).

- [ ] **Step 1: Create `app/javascript/controllers/inventory_exception_form_controller.js`**

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["qtyFields", "timeFields"]

  connect() {
    this.updateFields()
  }

  typeChanged() {
    this.updateFields()
  }

  updateFields() {
    const selected = this.element.querySelector('input[name="product_exception[exception_type]"]:checked')?.value
    const showQty  = selected === "override" || selected === "add"
    const showTime = selected === "override"

    this.qtyFieldsTarget.style.display  = showQty  ? "" : "none"
    this.timeFieldsTarget.style.display = showTime ? "" : "none"

    this.element.querySelectorAll(".type-opt").forEach(label => {
      const radio = label.querySelector("input[type=radio]")
      label.classList.toggle("sel", radio?.checked ?? false)
    })
  }
}
```

Since the app uses `eagerLoadControllersFrom` in `app/javascript/controllers/index.js`, the controller is auto-discovered by filename and maps to `data-controller="inventory-exception-form"` automatically — no manual registration needed.

- [ ] **Step 2: Start the dev server and verify the exception form**

```bash
bin/rails server
```

Visit `http://localhost:3000/staff/inventory`. Verify:
- "Skip" radio is selected by default, qty and time fields are hidden
- Clicking "Override" reveals both qty and time fields
- Clicking "Add" reveals qty field, hides time field
- Clicking "Skip" again hides both

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/inventory_exception_form_controller.js
git commit -m "feat: add inventory-exception-form Stimulus controller"
```

---

## Task 8: CSS

**Files:**
- Modify: `app/assets/stylesheets/application.css`

### Context

The exceptions section reuses the existing `.exc-row`, `.exc-date`, `.exc-reason`, `.hours-tag`, `.del-btn`, `.add-exc-row`, `.type-sel`, `.type-opt`, `.sel`, `.section-head`, `.section-card` classes already defined for the store hours exceptions — no new CSS needed for those.

Check whether any of these classes are missing (they were defined for store hours):

- [ ] **Step 1: Verify existing exception styles exist**

```bash
grep -n "exc-row\|exc-date\|type-sel\|type-opt\|add-exc-row" app/assets/stylesheets/application.css | head -20
```

If none of those are found, the store hours section must have defined them elsewhere. In that case, read the CSS file and locate the store hours exception styles to confirm they exist and will apply to the inventory exceptions section too.

- [ ] **Step 2: Add any missing styles**

Only add styles that are genuinely missing. The exceptions section intentionally reuses the store hours CSS — do not duplicate rules. If all the above classes already exist, this step is a no-op.

If `.exc-row`, `.exc-date`, `.type-sel`, `.type-opt`, `.add-exc-row` are all present, skip to Step 3.

If they are missing (unlikely), add them modelled on the store hours styles in the existing CSS.

- [ ] **Step 3: Start the server and do a visual check**

Visit `http://localhost:3000/staff/inventory`.

Confirm:
- The Products section and Exceptions section are both visually separated as `section-card` blocks
- Exception rows (if any exist) show date, product name, summary, × button in a horizontal row
- The add form shows date input, product select, type radios, and the conditional qty/time fields

- [ ] **Step 4: Commit only if CSS was changed**

```bash
git add app/assets/stylesheets/application.css
git commit -m "feat: add any missing inventory exception CSS"
```

If no changes were needed, skip the commit.

---

## Task 9: Cleanup — delete old products files

**Files:**
- Delete: `app/controllers/staff/products_controller.rb`
- Delete: `app/views/staff/products/index.html.erb`
- Delete: `app/views/staff/products/_product_form.html.erb`
- Delete: `spec/requests/staff/products_spec.rb`

### Context

The old products files are now dead code. The `/staff/products` route no longer exists (removed in Task 3). Deleting them prevents confusion.

- [ ] **Step 1: Delete the old files**

```bash
git rm app/controllers/staff/products_controller.rb
git rm app/views/staff/products/index.html.erb
git rm app/views/staff/products/_product_form.html.erb
git rm spec/requests/staff/products_spec.rb
```

- [ ] **Step 2: Run the full test suite**

```bash
bin/rspec
```

Expected: the old `products_spec.rb` is gone so its tests no longer run. All remaining specs pass. The two pre-existing failures (`user_spec.rb:15` and `store_hours_spec.rb:18`) may still be present — those are pre-existing and unrelated to this feature.

- [ ] **Step 3: Commit**

```bash
git commit -m "chore: remove old Staff::ProductsController and products views"
```

---

## Task 10: Deploy + smoke test

- [ ] **Step 1: Run the full test suite**

```bash
bin/rspec
```

Expected: all new specs pass.

- [ ] **Step 2: Deploy**

```bash
fly deploy
```

- [ ] **Step 3: Smoke test on https://massamater.fly.dev/staff/inventory**

Verify:
- Page loads with "Inventory" title
- Products section shows existing products with photos, day pills, edit (✏) and delete (×) buttons
- Edit a product (click ✏) → change name → Save → flash "Product saved." → name updated
- Add a product → fill form → Add → flash "Product created." → appears in list
- Delete a product → × → flash "Product deleted." → removed

- [ ] **Step 4: Smoke test exceptions**

- Select type "Skip", choose a product, pick a future date → Add → exception row appears with "Skip" label
- Select type "Override", choose a product, enter qty 99, pick a date → Add → row shows "Qty: 99"
- Select type "Override", enter qty and ready time → Add → row shows "Qty: X, HH:MM"
- Select type "Add", choose a product not normally on that day, enter qty → Add → row shows "Add — Qty: X"
- Click × on an exception → it disappears, flash "Exception removed."

- [ ] **Step 5: Verify nav**

- Only three nav links: Today, Inventory, Hours
- "Products" link no longer exists
- Clicking "Inventory" goes to `/staff/inventory`

- [ ] **Step 6: Confirm smoke test passed**
