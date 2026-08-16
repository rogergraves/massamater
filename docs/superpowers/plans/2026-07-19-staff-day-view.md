# Staff Day View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the placeholder staff dashboard with a real "Today" view showing today's available products (with reservation counts and progress bars) and today's uncollected reservations.

**Architecture:** The existing `Staff::DashboardController#index` action loads all data for the day. A `DayPresenter` plain Ruby object encapsulates the logic for computing which products are available today and their effective batch sizes (accounting for `ProductException` records). The view renders two `section-card` blocks using existing CSS classes; a new `day-view` CSS block adds only the styles that don't already exist.

**Tech Stack:** Rails 8.1.3, Ruby 4.0.1, RSpec request specs, plain Ruby presenter (no gems)

---

## Files

**Create:**
- `app/presenters/day_presenter.rb`
- `spec/presenters/day_presenter_spec.rb`
- `app/views/staff/dashboard/index.html.erb` (replace stub)
- `spec/requests/staff/dashboard_spec.rb`

**Modify:**
- `app/controllers/staff/dashboard_controller.rb`
- `config/locales/en.yml`
- `config/locales/pt.yml`
- `app/assets/stylesheets/application.css`

---

## Task 1: `DayPresenter` — available products for a given date

**Files:**
- Create: `app/presenters/day_presenter.rb`
- Create: `spec/presenters/day_presenter_spec.rb`

### Context

`DayPresenter` is a plain Ruby object initialized with a `date`. It computes which products are available on that date (active, scheduled for that day-of-week, not skipped) and each product's effective batch size and ready time (from `ProductException` overrides if present).

It also exposes the reservations for that date (active, uncollected).

The `product_schedule_days.day_of_week` column is an integer (0=Sunday … 6=Saturday) stored via an enum on `ProductScheduleDay`. Use `date.wday` to get today's day-of-week integer.

### Step 1: Write the spec

Create `spec/presenters/day_presenter_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe DayPresenter do
  let(:date) { Date.new(2026, 7, 20) } # Monday (wday=1)
  subject(:presenter) { DayPresenter.new(date) }

  let!(:product_mon) do
    p = Product.create!(
      name: "Baguette", name_en: "Baguette",
      default_ready_time: "09:00", default_daily_batch_size: 20,
      active: true, order: 1
    )
    p.product_schedule_days.create!(day_of_week: 1) # Monday
    p
  end

  let!(:product_wed) do
    p = Product.create!(
      name: "Croissant", name_en: "Croissant",
      default_ready_time: "08:00", default_daily_batch_size: 12,
      active: true, order: 2
    )
    p.product_schedule_days.create!(day_of_week: 3) # Wednesday
    p
  end

  let!(:inactive_product) do
    p = Product.create!(
      name: "Old Bread", name_en: "Old Bread",
      default_ready_time: "09:00", default_daily_batch_size: 5,
      active: false, order: 99
    )
    p.product_schedule_days.create!(day_of_week: 1)
    p
  end

  describe "#available_products" do
    it "includes only active products scheduled for that day" do
      ids = presenter.available_products.map(&:id)
      expect(ids).to include(product_mon.id)
      expect(ids).not_to include(product_wed.id)
      expect(ids).not_to include(inactive_product.id)
    end

    it "excludes products with a skip exception on that date" do
      ProductException.create!(product: product_mon, date: date, skipped: true)
      ids = presenter.available_products.map(&:id)
      expect(ids).not_to include(product_mon.id)
    end

    it "includes products with an add exception even if not normally scheduled" do
      ProductException.create!(
        product: product_wed, date: date, added: true, batch_size: 8
      )
      ids = presenter.available_products.map(&:id)
      expect(ids).to include(product_wed.id)
    end
  end

  describe "#effective_batch_size(product)" do
    it "returns the product's default batch size when no exception" do
      expect(presenter.effective_batch_size(product_mon)).to eq(20)
    end

    it "returns the override batch_size when an override exception with batch_size exists" do
      ProductException.create!(
        product: product_mon, date: date, batch_size: 35
      )
      expect(presenter.effective_batch_size(product_mon)).to eq(35)
    end

    it "returns the add exception batch_size for added products" do
      ProductException.create!(
        product: product_wed, date: date, added: true, batch_size: 8
      )
      expect(presenter.effective_batch_size(product_wed)).to eq(8)
    end

    it "returns the default when override exception has nil batch_size (time-only override)" do
      ProductException.create!(
        product: product_mon, date: date,
        batch_size: nil, ready_time_override: "10:00"
      )
      expect(presenter.effective_batch_size(product_mon)).to eq(20)
    end
  end

  describe "#effective_ready_time(product)" do
    it "returns the product default when no exception" do
      expect(presenter.effective_ready_time(product_mon).strftime("%H:%M")).to eq("09:00")
    end

    it "returns the override ready time when an override exception exists" do
      ProductException.create!(
        product: product_mon, date: date, ready_time_override: "10:30"
      )
      expect(presenter.effective_ready_time(product_mon).strftime("%H:%M")).to eq("10:30")
    end
  end

  describe "#reserved_count(product)" do
    it "returns 0 when no reservations" do
      expect(presenter.reserved_count(product_mon)).to eq(0)
    end

    it "sums reservation_items for active uncollected reservations on that date" do
      user = User.create!(name: "Ana", phone: "+351910000001", password: "password")
      r = Reservation.create!(user: user, date: date, source: :counter)
      ReservationItem.create!(reservation: r, product: product_mon, quantity: 3)
      expect(presenter.reserved_count(product_mon)).to eq(3)
    end

    it "excludes cancelled reservations" do
      user = User.create!(name: "Bob", phone: "+351910000002", password: "password")
      r = Reservation.create!(user: user, date: date, source: :counter, cancelled: true)
      ReservationItem.create!(reservation: r, product: product_mon, quantity: 5)
      expect(presenter.reserved_count(product_mon)).to eq(0)
    end

    it "excludes collected reservations" do
      user = User.create!(name: "Cat", phone: "+351910000003", password: "password")
      r = Reservation.create!(user: user, date: date, source: :counter,
                               collected_at: Time.current)
      ReservationItem.create!(reservation: r, product: product_mon, quantity: 2)
      expect(presenter.reserved_count(product_mon)).to eq(0)
    end
  end

  describe "#reservations" do
    it "returns active uncollected reservations for that date sorted by pickup_time" do
      user = User.create!(name: "Ana", phone: "+351910000011", password: "password")
      r1 = Reservation.create!(user: user, date: date, source: :counter, pickup_time: "10:00")
      r2 = Reservation.create!(user: user, date: date, source: :counter, pickup_time: "09:00")
      r3 = Reservation.create!(user: user, date: date, source: :counter, pickup_time: nil)
      expect(presenter.reservations.map(&:id)).to eq([r2.id, r1.id, r3.id])
    end

    it "excludes cancelled and collected reservations" do
      user = User.create!(name: "Ana", phone: "+351910000012", password: "password")
      Reservation.create!(user: user, date: date, source: :counter, cancelled: true)
      Reservation.create!(user: user, date: date, source: :counter,
                          collected_at: Time.current)
      expect(presenter.reservations).to be_empty
    end
  end
end
```

- [ ] **Step 2: Run the spec — expect FAIL**

```bash
bin/rspec spec/presenters/day_presenter_spec.rb 2>&1 | head -10
```

Expected: `uninitialized constant DayPresenter`

- [ ] **Step 3: Create `app/presenters/day_presenter.rb`**

```ruby
class DayPresenter
  def initialize(date)
    @date       = date
    @exceptions = ProductException.where(date: date).index_by(&:product_id)
    @counts     = reservation_counts
  end

  def available_products
    @available_products ||= begin
      skipped_ids = @exceptions.values.select(&:skipped?).map(&:product_id)
      added_ids   = @exceptions.values.select(&:added?).map(&:product_id)

      scheduled = Product.active
                         .ordered
                         .joins(:product_schedule_days)
                         .where(product_schedule_days: { day_of_week: @date.wday })
                         .where.not(id: skipped_ids)

      added = Product.active
                     .ordered
                     .where(id: added_ids)

      (scheduled + added).uniq.sort_by(&:order)
    end
  end

  def effective_batch_size(product)
    exc = @exceptions[product.id]
    return exc.batch_size if exc&.batch_size.present?
    product.default_daily_batch_size
  end

  def effective_ready_time(product)
    exc = @exceptions[product.id]
    exc&.ready_time_override || product.default_ready_time
  end

  def reserved_count(product)
    @counts[product.id] || 0
  end

  def reservations
    @reservations ||= Reservation
      .active
      .where(date: @date, collected_at: nil)
      .includes(reservation_items: :product)
      .joins(:user)
      .order(Arel.sql("pickup_time IS NULL, pickup_time ASC"))
  end

  def total_orders
    reservations.size
  end

  def total_items
    reservations.sum { |r| r.reservation_items.sum(&:quantity) }
  end

  private

  def reservation_counts
    ReservationItem
      .joins(:reservation)
      .where(
        reservations: {
          date: @date,
          cancelled: false,
          collected_at: nil
        }
      )
      .group(:product_id)
      .sum(:quantity)
  end
end
```

- [ ] **Step 4: Run the spec — expect PASS**

```bash
bin/rspec spec/presenters/day_presenter_spec.rb
```

Expected: all examples pass.

- [ ] **Step 5: Stage and report DONE (do NOT commit)**

```bash
git add app/presenters/day_presenter.rb spec/presenters/day_presenter_spec.rb
```

---

## Task 2: Controller, i18n, and request spec

**Files:**
- Modify: `app/controllers/staff/dashboard_controller.rb`
- Create: `spec/requests/staff/dashboard_spec.rb`
- Modify: `config/locales/en.yml`
- Modify: `config/locales/pt.yml`

### Context

The controller just instantiates `DayPresenter` and assigns it to `@day`. The view does the rest. The request spec verifies the page loads (200) and redirects to login when unauthenticated.

### Step 1: Write the request spec

Create `spec/requests/staff/dashboard_spec.rb`:

```ruby
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
```

- [ ] **Step 2: Run the spec — expect FAIL** (controller action doesn't load data yet)

```bash
bin/rspec spec/requests/staff/dashboard_spec.rb 2>&1 | head -10
```

Note: may pass already (empty controller renders view with no data). That's fine — proceed to step 3.

- [ ] **Step 3: Update `app/controllers/staff/dashboard_controller.rb`**

```ruby
module Staff
  class DashboardController < Staff::BaseController
    def index
      @day = DayPresenter.new(Date.current)
    end
  end
end
```

- [ ] **Step 4: Add i18n keys to `config/locales/en.yml`**

Add a `staff.dashboard:` block (replace the existing placeholder key):

```yaml
    dashboard:
      title: "Today"
      products_title: "Products"
      products_empty: "No products scheduled for today."
      reservations_title: "Reservations"
      reservations_empty: "No reservations for today."
      new_reservation_btn: "+ New reservation"
      orders_summary: "%{orders} orders · %{items} items"
      ready_at: "Ready %{time}"
```

- [ ] **Step 5: Add i18n keys to `config/locales/pt.yml`**

```yaml
    dashboard:
      title: "Hoje"
      products_title: "Produtos"
      products_empty: "Sem produtos programados para hoje."
      reservations_title: "Reservas"
      reservations_empty: "Sem reservas para hoje."
      new_reservation_btn: "+ Nova reserva"
      orders_summary: "%{orders} encomendas · %{items} itens"
      ready_at: "Pronto às %{time}"
```

- [ ] **Step 6: Run the spec — expect PASS**

```bash
bin/rspec spec/requests/staff/dashboard_spec.rb
```

Expected: 2 examples, 0 failures.

- [ ] **Step 7: Stage and report DONE (do NOT commit)**

```bash
git add app/controllers/staff/dashboard_controller.rb spec/requests/staff/dashboard_spec.rb config/locales/en.yml config/locales/pt.yml
```

---

## Task 3: View

**Files:**
- Modify (replace): `app/views/staff/dashboard/index.html.erb`

### Context

Two `section-card` blocks, matching the style of the Inventory and Store Hours pages.

**Products section:** iterate `@day.available_products`. For each, show photo (or placeholder), name, ready time, reserved/total counts, and a progress bar. The progress bar is a `<div class="prog-bar">` containing `<div class="prog-fill">` with inline `width` style set to the percentage. Fill color changes via CSS classes: `prog-fill--warn` (≥75%), `prog-fill--full` (≥100%).

**Reservations section:** header with order/item summary and a "+ New reservation" placeholder button. Each reservation row shows pickup time (or "–"), customer name, and items as "Product name ×N" spans.

### Step 1: Replace `app/views/staff/dashboard/index.html.erb`

```erb
<%# app/views/staff/dashboard/index.html.erb %>
<div class="wrap">

  <div class="topbar">
    <div>
      <div class="pg-title"><%= t("staff.dashboard.title") %></div>
      <div class="pg-sub"><%= Date.current.strftime("%A, %b %-d") %></div>
    </div>
  </div>

  <%# Products section %>
  <div class="section-card">
    <div class="section-head">
      <div class="section-head-title"><%= t("staff.dashboard.products_title") %></div>
    </div>

    <% if @day.available_products.empty? %>
      <p class="empty-msg"><%= t("staff.dashboard.products_empty") %></p>
    <% else %>
      <% @day.available_products.each do |product| %>
        <% total    = @day.effective_batch_size(product) %>
        <% reserved = @day.reserved_count(product) %>
        <% pct      = total > 0 ? [(reserved * 100 / total), 100].min : 0 %>
        <% fill_class = pct >= 100 ? "prog-fill--full" : pct >= 75 ? "prog-fill--warn" : "" %>

        <div class="day-product-row">
          <div class="day-prod-photo">
            <% if product.photo.attached? %>
              <%= image_tag product.photo, class: "day-prod-img" %>
            <% else %>
              <div class="day-prod-img-placeholder"></div>
            <% end %>
          </div>

          <div class="day-prod-info">
            <div class="day-prod-name"><%= product.display_name %></div>
            <div class="day-prod-meta">
              <%= t("staff.dashboard.ready_at", time: @day.effective_ready_time(product).strftime("%H:%M")) %>
            </div>
          </div>

          <div class="day-prod-counts">
            <span class="day-count"><%= reserved %> / <%= total %></span>
            <div class="prog-bar">
              <div class="prog-fill <%= fill_class %>" style="width:<%= pct %>%"></div>
            </div>
          </div>
        </div>
      <% end %>
    <% end %>
  </div>

  <%# Reservations section %>
  <div class="section-card">
    <div class="section-head">
      <div>
        <div class="section-head-title"><%= t("staff.dashboard.reservations_title") %></div>
        <% if @day.total_orders > 0 %>
          <div class="section-head-sub">
            <%= t("staff.dashboard.orders_summary",
                  orders: @day.total_orders,
                  items:  @day.total_items) %>
          </div>
        <% end %>
      </div>
      <a href="#" class="add-btn-sm"><%= t("staff.dashboard.new_reservation_btn") %></a>
    </div>

    <% if @day.reservations.empty? %>
      <p class="empty-msg"><%= t("staff.dashboard.reservations_empty") %></p>
    <% else %>
      <% @day.reservations.each do |reservation| %>
        <div class="day-res-row">
          <div class="day-res-time">
            <%= reservation.pickup_time ? reservation.pickup_time.strftime("%H:%M") : "–" %>
          </div>
          <div class="day-res-info">
            <div class="day-res-name"><%= reservation.user.name %></div>
            <div class="day-res-items">
              <% reservation.reservation_items.each do |item| %>
                <span class="day-res-item">
                  <%= item.product.display_name %> ×<%= item.quantity %>
                </span>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    <% end %>
  </div>

</div>
```

- [ ] **Step 2: Run the full request spec to confirm view renders**

```bash
bin/rspec spec/requests/staff/dashboard_spec.rb
```

Expected: 2 examples, 0 failures.

- [ ] **Step 3: Stage and report DONE (do NOT commit)**

```bash
git add app/views/staff/dashboard/index.html.erb
```

---

## Task 4: CSS

**Files:**
- Modify: `app/assets/stylesheets/application.css`

### Context

Existing classes used by the view: `.wrap`, `.topbar`, `.pg-title`, `.pg-sub`, `.section-card`, `.section-head`, `.section-head-title`, `.section-head-sub`, `.add-btn-sm`, `.empty-msg` — verify each exists before adding.

New classes needed: `.day-product-row`, `.day-prod-photo`, `.day-prod-img`, `.day-prod-img-placeholder`, `.day-prod-info`, `.day-prod-name`, `.day-prod-meta`, `.day-prod-counts`, `.day-count`, `.prog-bar`, `.prog-fill`, `.prog-fill--warn`, `.prog-fill--full`, `.day-res-row`, `.day-res-time`, `.day-res-info`, `.day-res-name`, `.day-res-items`, `.day-res-item`.

- [ ] **Step 1: Check which new classes are already in application.css**

```bash
grep -n "day-product\|day-prod\|day-res\|prog-bar\|prog-fill\|empty-msg" app/assets/stylesheets/application.css
```

- [ ] **Step 2: Add missing styles to `app/assets/stylesheets/application.css`**

Append after the last existing rule block:

```css
/* Day view */
.empty-msg        { padding:16px;color:#9b8a6e;font-size:13px }

.day-product-row  { display:flex;align-items:center;gap:12px;padding:10px 16px;border-bottom:1px solid #f0e8da }
.day-product-row:last-child { border-bottom:none }
.day-prod-photo   { flex-shrink:0 }
.day-prod-img     { width:40px;height:40px;object-fit:cover;border-radius:8px }
.day-prod-img-placeholder { width:40px;height:40px;border-radius:8px;background:#ede5d8 }
.day-prod-info    { flex:1;min-width:0 }
.day-prod-name    { font-size:14px;font-weight:600;color:#2b2b2b }
.day-prod-meta    { font-size:12px;color:#9b8a6e;margin-top:2px }
.day-prod-counts  { display:flex;flex-direction:column;align-items:flex-end;gap:4px;min-width:90px }
.day-count        { font-size:13px;font-weight:600;color:#2b2b2b }
.prog-bar         { width:90px;height:6px;background:#ede5d8;border-radius:3px;overflow:hidden }
.prog-fill        { height:100%;background:#7a4f2b;border-radius:3px;transition:width 0.2s }
.prog-fill--warn  { background:#d97706 }
.prog-fill--full  { background:#c62828 }

.day-res-row      { display:flex;gap:12px;padding:10px 16px;border-bottom:1px solid #f0e8da }
.day-res-row:last-child { border-bottom:none }
.day-res-time     { width:44px;flex-shrink:0;font-size:13px;font-weight:600;color:#7a4f2b;padding-top:2px }
.day-res-info     { flex:1 }
.day-res-name     { font-size:14px;font-weight:600;color:#2b2b2b }
.day-res-items    { display:flex;flex-wrap:wrap;gap:6px;margin-top:3px }
.day-res-item     { font-size:12px;color:#6b5d45;background:#f4efe7;border-radius:5px;padding:2px 7px }
```

- [ ] **Step 3: Verify the section-head in reservations section has flex layout**

The reservations section-head needs to flex its title+sub on the left and the "+ New reservation" button on the right. Check if `.section-head` already does this:

```bash
grep "section-head " app/assets/stylesheets/application.css
```

If `.section-head` doesn't already use `display:flex;justify-content:space-between`, add a modifier class or inline style. The view uses `<div class="section-head">` — add a new rule:

```css
.section-head     { display:flex;align-items:center;justify-content:space-between }
```

But check the existing rule first — if it already has `display:flex`, skip this.

- [ ] **Step 4: Run the request spec to confirm no regressions**

```bash
bin/rspec spec/requests/staff/dashboard_spec.rb
```

- [ ] **Step 5: Stage and report DONE (do NOT commit)**

```bash
git add app/assets/stylesheets/application.css
```

---

## Task 5: Deploy + smoke test

**Files:** none (deployment only)

- [ ] **Step 1: Run the full test suite**

```bash
bin/rspec
```

Expected: all new specs pass. Pre-existing failures in `user_spec.rb` (phone format) and `store_hours_spec.rb` are unrelated — ignore them.

- [ ] **Step 2: Commit all staged changes**

```bash
git add -p  # review any unstaged changes
git commit -m "feat: staff day view with products, progress bars, and reservations"
```

Note: a hook blocks `git commit *` — the human partner does the committing. Stage all files and report DONE with the commit message to use.

- [ ] **Step 3: Deploy**

```bash
fly deploy
```

- [ ] **Step 4: Smoke test at https://massamater.fly.dev/staff**

Verify:
- Page title "Today — {weekday}, {date}"
- Products section shows today's active scheduled products
- Each product row shows photo (or placeholder), name, ready time, reserved/total, progress bar
- Exceptions are respected: skipped products absent, overrides show correct batch size
- Reservations section shows today's active uncollected reservations sorted by pickup time
- Each reservation shows customer name and items
- "+ New reservation" button visible (links to `#` for now)
- Empty states show if no products / no reservations
