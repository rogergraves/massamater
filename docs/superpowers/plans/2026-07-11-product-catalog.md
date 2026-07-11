# Product Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the staff product catalog page where bakery items can be listed, created, edited (inline), and deleted.

**Architecture:** A single `Staff::ProductsController` handles the index/create/update/destroy actions. All product forms live in the DOM on the index page and are toggled visible via a Stimulus `product-catalog` controller — no Turbo Frames or separate edit pages needed. Day schedule checkboxes are styled like the existing type-opt pattern; store-closed days are greyed out and disabled using `@open_days` loaded from `StoreHour`.

**Tech Stack:** Rails 8.1.3, Ruby 4.0.1 (RVM gemset `massamater`), Active Storage (already configured), Stimulus (Hotwire), RSpec request specs, i18n (PT default, EN).

---

## File Map

| File | Action |
|------|--------|
| `config/routes.rb` | Add `resources :products, only: [:index, :create, :update, :destroy]` inside `namespace :staff` |
| `app/views/layouts/staff.html.erb` | Update nav "Produtos/Products" link from `"#"` to `staff_products_path` |
| `config/locales/pt.yml` | Add `staff.products.*` keys |
| `config/locales/en.yml` | Add `staff.products.*` keys |
| `app/controllers/staff/products_controller.rb` | Create — index, create, update, destroy |
| `app/views/staff/products/index.html.erb` | Create — list page with inline forms |
| `app/javascript/controllers/product_catalog_controller.js` | Create — toggle new/edit forms, day-box checked state |
| `app/assets/stylesheets/application.css` | Append product catalog CSS |
| `spec/requests/staff/products_spec.rb` | Create — request specs |

---

### Task 1: Routes + nav link

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/views/layouts/staff.html.erb`

- [ ] **Step 1: Write the failing route test**

```ruby
# spec/routing/staff/products_routing_spec.rb
require "rails_helper"

RSpec.describe "Staff::Products routing", type: :routing do
  it "routes GET /staff/products to staff/products#index" do
    expect(get: "/staff/products").to route_to("staff/products#index")
  end

  it "routes POST /staff/products to staff/products#create" do
    expect(post: "/staff/products").to route_to("staff/products#create")
  end

  it "routes PATCH /staff/products/1 to staff/products#update" do
    expect(patch: "/staff/products/1").to route_to("staff/products#update", id: "1")
  end

  it "routes DELETE /staff/products/1 to staff/products#destroy" do
    expect(delete: "/staff/products/1").to route_to("staff/products#destroy", id: "1")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/routing/staff/products_routing_spec.rb -f doc
```

Expected: FAIL — no route matches

- [ ] **Step 3: Add route**

In `config/routes.rb`, add inside `namespace :staff do`:

```ruby
namespace :staff do
  root "dashboard#index"
  resource  :store_hours,      only: [:edit, :update]
  resources :store_exceptions, only: [:create, :destroy]
  resources :products,         only: [:index, :create, :update, :destroy]
end
```

- [ ] **Step 4: Update nav link**

In `app/views/layouts/staff.html.erb`, change:

```erb
<%= link_to t("staff.nav.products"),  "#",                          class: "nav-link" %>
```

to:

```erb
<%= link_to t("staff.nav.products"),  staff_products_path,          class: "nav-link" %>
```

- [ ] **Step 5: Run test to verify it passes**

```bash
bundle exec rspec spec/routing/staff/products_routing_spec.rb -f doc
```

Expected: 4 examples, 0 failures

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/views/layouts/staff.html.erb spec/routing/staff/products_routing_spec.rb
git commit -m "feat: add staff products routes and nav link"
```

---

### Task 2: i18n strings

**Files:**
- Modify: `config/locales/pt.yml`
- Modify: `config/locales/en.yml`

- [ ] **Step 1: Add PT strings**

In `config/locales/pt.yml`, under `pt: > staff:`, add a `products:` block (alongside `nav:` and `dashboard:`):

```yaml
    products:
      title: "Catálogo de produtos"
      subtitle: "Foto, horário, tempo de preparação e estado"
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
```

- [ ] **Step 2: Add EN strings**

In `config/locales/en.yml`, under `en: > staff:`, add a `products:` block:

```yaml
    products:
      title: "Product catalog"
      subtitle: "Photo, schedule, default ready time, and status"
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
```

- [ ] **Step 3: Verify no missing keys**

```bash
bundle exec rails runner "I18n.locale = :pt; puts I18n.t('staff.products.title')"
bundle exec rails runner "I18n.locale = :en; puts I18n.t('staff.products.title')"
```

Expected:
```
Catálogo de produtos
Product catalog
```

- [ ] **Step 4: Commit**

```bash
git add config/locales/pt.yml config/locales/en.yml
git commit -m "feat: add i18n strings for staff product catalog"
```

---

### Task 3: ProductsController + request spec

**Files:**
- Create: `app/controllers/staff/products_controller.rb`
- Create: `spec/requests/staff/products_spec.rb`

The controller:
- `index` — loads all products ordered, their schedule days, open store days, and a blank new product
- `create` — saves new product + schedule, redirects; on error re-renders index
- `update` — updates product + schedule, redirects; on error re-renders index with `@editing_product_id` set so the inline form stays open
- `destroy` — deletes product, redirects

Schedule saving: day checkboxes submit as `params[:day_of_week]` (an array of day-of-week integers as strings). The private `save_schedule` method reconciles this against existing `ProductScheduleDay` records.

- [ ] **Step 1: Write the failing request spec**

```ruby
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/requests/staff/products_spec.rb -f doc
```

Expected: FAIL — uninitialized constant Staff::ProductsController

- [ ] **Step 3: Create the controller**

```ruby
# app/controllers/staff/products_controller.rb
class Staff::ProductsController < Staff::BaseController
  def index
    @products  = Product.ordered.includes(:product_schedule_days)
    @open_days = StoreHour.where(open: true).pluck(:day_of_week)
    @new_product = Product.new
  end

  def create
    @product = Product.new(product_params)
    if @product.save
      save_schedule(@product)
      redirect_to staff_products_path, notice: t("staff.products.created")
    else
      @products  = Product.ordered.includes(:product_schedule_days)
      @open_days = StoreHour.where(open: true).pluck(:day_of_week)
      @new_product = @product
      @show_new_form = true
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @product = Product.find(params[:id])
    if @product.update(product_params)
      save_schedule(@product)
      redirect_to staff_products_path, notice: t("staff.products.saved")
    else
      @products  = Product.ordered.includes(:product_schedule_days)
      @open_days = StoreHour.where(open: true).pluck(:day_of_week)
      @new_product = Product.new
      @editing_product_id = @product.id
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    Product.find(params[:id]).destroy
    redirect_to staff_products_path, notice: t("staff.products.deleted")
  end

  private

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

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/requests/staff/products_spec.rb -f doc
```

Expected: 7 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/controllers/staff/products_controller.rb spec/requests/staff/products_spec.rb
git commit -m "feat: add Staff::ProductsController with request specs"
```

---

### Task 4: Products index view

**Files:**
- Create: `app/views/staff/products/index.html.erb`

The view renders:
- Page header + "New product" button
- A hidden new-product form (shown by Stimulus when button is clicked)
- A list of product rows, each with:
  - Collapsed summary (photo placeholder, name, day pills, edit/delete buttons)
  - Hidden expanded form (shown by Stimulus when edit is clicked)
- Validation errors appear inline above the relevant form

The whole page is wrapped in `data-controller="product-catalog"` and `data-product-catalog-open-id-value="<%= @editing_product_id %>"` so on re-render after a validation error, the right form auto-opens.

Day pills: 7 boxes M-S, brown if the product is available that day, grey otherwise. Use the first letter of each day from `I18n.t("date.day_names")`.

Day toggles in the form: a `<label class="day-box">` wrapping a hidden checkbox. Closed store days get `.closed-day` class and `disabled: true`. Active days get `.checked` class. Clicking a day box fires `change->product-catalog#toggleDayBox` which toggles the `.checked` class.

- [ ] **Step 1: Create the view**

```erb
<%# app/views/staff/products/index.html.erb %>
<div class="wrap"
     data-controller="product-catalog"
     data-product-catalog-open-id-value="<%= @editing_product_id %>">

  <div class="topbar">
    <div>
      <div class="pg-title"><%= t("staff.products.title") %></div>
      <div class="pg-sub"><%= t("staff.products.subtitle") %></div>
    </div>
    <button class="add-btn"
            data-action="click->product-catalog#showNew"
            data-product-catalog-target="newBtn">
      <%= t("staff.products.new_btn") %>
    </button>
  </div>

  <%# ── New product form (hidden by default) ─────────────── %>
  <div data-product-catalog-target="newForm" style="display:none" class="section-card">
    <div class="section-head">
      <div class="section-head-title"><%= t("staff.products.new_title") %></div>
    </div>
    <%= form_with model: @new_product, url: staff_products_path, multipart: true do |f| %>
      <%= render "product_form", f: f, product: @new_product, open_days: @open_days, show_errors: @show_new_form %>
      <div class="form-actions">
        <%= f.submit t("staff.products.add_btn"), class: "save-btn" %>
        <button type="button" class="cancel-btn" data-action="click->product-catalog#hideNew">
          <%= t("staff.products.cancel_btn") %>
        </button>
      </div>
    <% end %>
  </div>

  <%# ── Product list ───────────────────────────────────────── %>
  <div class="prod-list">
    <% @products.each do |product| %>
      <% editing = @editing_product_id == product.id %>
      <div class="prod-row" id="prod-row-<%= product.id %>">

        <%# Collapsed summary (hidden when editing) %>
        <div id="product-summary-<%= product.id %>"
             class="prod-main"
             style="<%= 'display:none' if editing %>">

          <div class="photo-cell <%= 'empty' unless product.photo.attached? %>">
            <% if product.photo.attached? %>
              <%= image_tag product.photo, class: "prod-photo" %>
            <% else %>
              + photo
            <% end %>
          </div>

          <div class="prod-name <%= 'inactive' unless product.active? %>">
            <%= product.display_name %>
            <% unless product.active? %>
              <span class="inactive-badge"><%= t("staff.products.inactive_badge") %></span>
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
                          staff_product_path(product),
                          method: :delete,
                          class: "icon-btn danger" %>
          </div>
        </div>

        <%# Expanded edit form (shown when editing) %>
        <div id="product-form-<%= product.id %>"
             style="<%= 'display:none' unless editing %>">
          <%= form_with model: product, url: staff_product_path(product), method: :patch, multipart: true do |f| %>
            <%= render "product_form", f: f, product: product, open_days: @open_days, show_errors: editing %>
            <div class="form-actions">
              <%= f.submit t("staff.products.save_btn"), class: "save-btn" %>
              <button type="button" class="cancel-btn"
                      data-action="click->product-catalog#close"
                      data-product-id="<%= product.id %>">
                <%= t("staff.products.cancel_btn") %>
              </button>
            </div>
          <% end %>
        </div>

      </div>
    <% end %>
  </div>

</div>
```

- [ ] **Step 2: Create the shared form partial**

```erb
<%# app/views/staff/products/_product_form.html.erb %>
<div class="prod-detail">
  <% if show_errors && product.errors.any? %>
    <div class="form-errors"><%= product.errors.full_messages.to_sentence %></div>
  <% end %>

  <div class="detail-row">
    <div class="detail-field">
      <%= f.label :name, t("staff.products.name_label"), class: "detail-label" %>
      <%= f.text_field :name, class: "name-in" %>
    </div>
    <div class="detail-field">
      <%= f.label :name_en, t("staff.products.name_en_label"), class: "detail-label" %>
      <%= f.text_field :name_en, class: "name-in" %>
    </div>
  </div>

  <div class="detail-label" style="margin-top:14px"><%= t("staff.products.schedule_label") %></div>
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

  <div class="detail-row" style="margin-top:14px">
    <div class="detail-field">
      <%= f.label :default_ready_time, t("staff.products.ready_time_label"), class: "detail-label" %>
      <%= f.time_field :default_ready_time, class: "time-in" %>
    </div>
    <div class="detail-field">
      <%= f.label :default_daily_batch_size, t("staff.products.batch_size_label"), class: "detail-label" %>
      <%= f.number_field :default_daily_batch_size, min: 1, class: "num-in" %>
    </div>
    <div class="detail-field">
      <%= f.label :max_reservable_quantity_per_client, t("staff.products.max_per_client_label"), class: "detail-label" %>
      <%= f.number_field :max_reservable_quantity_per_client, min: 1, placeholder: "∞", class: "num-in" %>
    </div>
    <div class="detail-field">
      <%= f.label :order, t("staff.products.order_label"), class: "detail-label" %>
      <%= f.number_field :order, min: 0, class: "num-in" %>
    </div>
    <div class="detail-field">
      <div class="detail-label"><%= t("staff.products.active_label") %></div>
      <label class="toggle <%= 'off' unless product.active? %>">
        <%= f.check_box :active, class: "sr-only",
                        data: { action: "change->product-catalog#toggleActive" } %>
        <div class="knob"></div>
      </label>
    </div>
    <div class="detail-field">
      <%= f.label :photo, t("staff.products.photo_label"), class: "detail-label" %>
      <%= f.file_field :photo, accept: "image/*", class: "photo-in" %>
    </div>
  </div>
</div>
```

- [ ] **Step 3: Verify the page loads (no syntax errors)**

Start the server:
```bash
bin/rails server
```

Visit `http://localhost:3000/staff/products` (log in first at `/login` with `+351912000001` / `password`).

Expected: Page loads without error, shows product list.

- [ ] **Step 4: Commit**

```bash
git add app/views/staff/products/
git commit -m "feat: add staff products index view with inline forms"
```

---

### Task 5: Stimulus product-catalog controller

**Files:**
- Create: `app/javascript/controllers/product_catalog_controller.js`

This controller:
- `connect()` — reads `openIdValue`; if set, calls `openProduct(id)` to auto-open the form after a validation error re-render
- `showNew()` — shows new form div, hides new-product button
- `hideNew()` — hides new form div, shows new-product button
- `open(event)` — reads `productId` from `event.currentTarget.dataset`, shows form div, hides summary div
- `close(event)` — reads `productId`, hides form div, shows summary div
- `toggleDayBox(event)` — toggles `.checked` class on the parent `<label>` based on checkbox state
- `toggleActive(event)` — toggles `.off` class on the parent `.toggle` label

- [ ] **Step 1: Create the controller**

```javascript
// app/javascript/controllers/product_catalog_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["newForm", "newBtn"]
  static values  = { openId: Number }

  connect() {
    if (this.openIdValue) this.openProduct(this.openIdValue)
  }

  showNew() {
    this.newFormTarget.style.display = ""
    this.newBtnTarget.style.display  = "none"
  }

  hideNew() {
    this.newFormTarget.style.display = "none"
    this.newBtnTarget.style.display  = ""
  }

  open(event) {
    this.openProduct(event.currentTarget.dataset.productId)
  }

  close(event) {
    const id = event.currentTarget.dataset.productId
    document.getElementById(`product-summary-${id}`).style.display = ""
    document.getElementById(`product-form-${id}`).style.display    = "none"
  }

  toggleDayBox(event) {
    event.currentTarget.closest("label").classList.toggle("checked", event.currentTarget.checked)
  }

  toggleActive(event) {
    event.currentTarget.closest(".toggle").classList.toggle("off", !event.currentTarget.checked)
  }

  openProduct(id) {
    document.getElementById(`product-summary-${id}`).style.display = "none"
    document.getElementById(`product-form-${id}`).style.display    = ""
  }
}
```

- [ ] **Step 2: Verify controller loads**

Visit `http://localhost:3000/staff/products` and open the browser console.

Run:
```javascript
document.querySelector('[data-controller="product-catalog"]')
```

Expected: returns the wrapper div (not null)

- [ ] **Step 3: Verify edit toggle works**

Click the ✏ button on any product row. Expected: the collapsed summary hides and the expanded form appears in its place.

Click "Cancel". Expected: the form hides and the collapsed summary returns.

- [ ] **Step 4: Verify day toggles work**

Open a product's edit form. Click on a day box that is enabled. Expected: the `.checked` brown background toggles on/off.

- [ ] **Step 5: Verify active toggle works**

Open a product's edit form. Click the active toggle. Expected: toggle switches between brown (on) and grey (off) visually.

- [ ] **Step 6: Commit**

```bash
git add app/javascript/controllers/product_catalog_controller.js
git commit -m "feat: add product-catalog Stimulus controller"
```

---

### Task 6: CSS styles

**Files:**
- Modify: `app/assets/stylesheets/application.css`

Existing classes already in use (do NOT redefine):
- `.wrap`, `.topbar`, `.pg-title`, `.pg-sub`, `.section-card`, `.section-head`, `.section-head-title`, `.section-head-sub`
- `.save-btn`, `.time-in`, `.toggle`, `.toggle.off`, `.toggle .knob`, `.sr-only`
- `.flash-notice`, `.flash-alert`

New classes needed (append to end of file):

- [ ] **Step 1: Append product catalog styles**

```css
/* ── Product Catalog ─────────────────────────────── */
.add-btn          { background:#7a4f2b;color:#fff;border:none;padding:10px 18px;border-radius:10px;font-size:14px;font-weight:700;cursor:pointer }
.add-btn:hover    { background:#5c3a1f }
.prod-list        { background:#fff;border-radius:12px;overflow:hidden;border:1px solid #e3d9c8;margin-bottom:14px }
.prod-row         { border-bottom:1px solid #ede5d8 }
.prod-row:last-child { border-bottom:none }
.prod-main        { display:flex;align-items:center;gap:14px;padding:13px 16px }
.photo-cell       { width:52px;height:52px;border-radius:9px;background:#efe2cd;display:flex;align-items:center;justify-content:center;font-size:24px;flex:0 0 auto;overflow:hidden }
.photo-cell.empty { border:2px dashed #c8b89a;font-size:12px;color:#c8b89a;text-align:center;line-height:1.3 }
.prod-photo       { width:52px;height:52px;object-fit:cover;border-radius:9px }
.prod-name        { flex:1;font-size:15px;font-weight:700;color:#2b2b2b }
.prod-name.inactive { color:#9b8a6e }
.inactive-badge   { font-size:11px;font-weight:400;color:#9b8a6e;margin-left:4px }
.day-pills        { display:flex;gap:4px }
.dp               { width:26px;height:26px;border-radius:6px;font-size:11px;font-weight:700;display:flex;align-items:center;justify-content:center;background:#f0ede8;color:#b0a898 }
.dp.on            { background:#7a4f2b;color:#fff }
.row-actions      { display:flex;gap:6px;flex:0 0 auto;align-items:center }
.icon-btn         { width:34px;height:34px;border-radius:7px;border:1px solid #e3d9c8;background:#fff;color:#6b5d45;cursor:pointer;display:flex;align-items:center;justify-content:center;font-size:16px;line-height:1 }
.icon-btn.danger  { color:#c62828;border-color:#fca08a }
.icon-btn.danger:hover { background:#fdecea }
.prod-detail      { background:#faf3e9;border-top:1px solid #e8ddd0;padding:14px 16px 16px }
.detail-label     { font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.4px;color:#b08c5e;margin-bottom:6px;display:block }
.day-grid         { display:flex;gap:8px;flex-wrap:wrap;margin-bottom:4px }
.day-toggle       { display:flex;flex-direction:column;align-items:center;gap:5px }
.day-label        { font-size:11px;font-weight:700;color:#9b8a6e }
.day-box          { width:38px;height:38px;border-radius:9px;border:2px solid #e3d9c8;background:#fff;display:flex;align-items:center;justify-content:center;font-size:13px;font-weight:700;color:#9b8a6e;cursor:pointer }
.day-box.checked  { background:#7a4f2b;border-color:#7a4f2b;color:#fff }
.day-box.closed-day { background:#f0ede8;border-color:#e3d9c8;color:#ccc;cursor:not-allowed }
.detail-row       { display:flex;align-items:flex-end;gap:20px;flex-wrap:wrap }
.detail-field     { display:flex;flex-direction:column;gap:4px }
.name-in          { border:2px solid #e3d9c8;border-radius:7px;padding:8px 10px;font-size:14px;font-weight:600;color:#2b2b2b;background:#fdfbf7;min-width:160px }
.num-in           { border:2px solid #e3d9c8;border-radius:7px;padding:7px 9px;font-size:13px;font-weight:700;color:#2b2b2b;background:#fdfbf7;width:70px;text-align:center }
.photo-in         { font-size:12px;color:#6b5d45 }
.form-actions     { display:flex;align-items:center;gap:10px;padding:12px 16px;background:#faf3e9;border-top:1px solid #ede5d8 }
.cancel-btn       { background:transparent;border:1.5px solid #c8b89a;color:#6b5d45;padding:8px 16px;border-radius:8px;font-size:13px;font-weight:600;cursor:pointer }
.cancel-btn:hover { background:#f0ede8 }
.row-actions form { display:inline }
```

- [ ] **Step 2: Verify visually**

Reload `http://localhost:3000/staff/products`.

Check:
- Product list renders with photo cells, name, day pills, edit/delete buttons
- Inactive products (e.g. "Bolachas") show in grey with "(inactive)" badge
- Clicking ✏ opens the expanded detail panel with brown background, day grid, and fields
- Active toggle looks identical to the store hours toggle
- Day boxes are brown when selected, grey when not, muted when store is closed that day

- [ ] **Step 3: Commit**

```bash
git add app/assets/stylesheets/application.css
git commit -m "feat: add CSS styles for staff product catalog"
```

---

### Task 7: Deploy + smoke test

**Files:** none (deployment only)

- [ ] **Step 1: Run full test suite**

```bash
bundle exec rspec --format progress
```

Expected: All examples passing, 0 failures.

- [ ] **Step 2: Deploy to Fly.io**

```bash
fly deploy
```

Expected: Deployment completes with `v{N} deployed successfully`.

- [ ] **Step 3: Smoke test on massamater.fly.dev**

1. Log in at `massamater.fly.dev/login` with `+351912000001` / `password`
2. Click "Produtos" in nav → should land on product catalog page
3. Verify all 5 seed products are listed (Baguete, Broa de Milho, Cinnamon Rolls, Granola, Bolachas)
4. Bolachas should appear greyed/inactive
5. Click ✏ on Baguete → expanded form opens below the row
6. Change the name to "Baguete Especial", click "Guardar" → redirects to list, name updated
7. Click "Novo produto" → form appears at top
8. Fill in name "Teste", ready time "08:00", batch size "5", check Tuesday and Wednesday, click "Adicionar"
9. New product appears in list with Ter/Qua pills lit
10. Click × on "Teste" product → product deleted, gone from list
11. Click "EN" locale → day pill letters change, inactive badge changes to "(inactive)"

- [ ] **Step 4: Commit any smoke test fixes (if needed)**

```bash
git add -p
git commit -m "fix: <describe what was fixed during smoke test>"
```
