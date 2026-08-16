# Staff Day View — Closed Day with Next-Open Preview

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When today is a closed day, show a "Store closed today" notice and a preview of the next open day's available products instead of an empty products section.

**Architecture:** `DayPresenter` gains a `store_open?` class method and a `next_open_date` helper that walks forward up to 14 days checking `StoreHour` and `StoreException`. The controller passes both `@day` (always today) and `@next_day` (next open date, or nil if already open) to the view. The view conditionally renders a closed notice + next-day products section instead of the normal products + reservations layout.

**Tech Stack:** Rails 8.1.3, Ruby 4.0.1 (RVM gemset `massamater`), RSpec, SQLite3. Run specs: `~/.rvm/bin/rvm-shell ruby-4.0.1@massamater -c "bundle exec rspec <path>"`.

---

## File Map

| File | Change |
|---|---|
| `app/presenters/day_presenter.rb` | Add `DayPresenter.open_on?(date)` and `DayPresenter.next_open_date(from:)` class methods |
| `app/controllers/staff/dashboard_controller.rb` | Set `@next_day` when today is closed |
| `app/views/staff/dashboard/index.html.erb` | Conditional layout: closed notice + next-day preview OR normal today view |
| `config/locales/en.yml` | Add `staff.dashboard.closed_today`, `staff.dashboard.next_open`, `staff.dashboard.next_open_products_title` |
| `config/locales/pt.yml` | Same keys in Portuguese |
| `spec/presenters/day_presenter_spec.rb` | Add examples for `open_on?` and `next_open_date` |
| `spec/requests/staff/dashboard_spec.rb` | Add example for closed-day rendering |

---

### Task 1: DayPresenter — `open_on?` and `next_open_date`

**Files:**
- Modify: `app/presenters/day_presenter.rb`
- Modify: `spec/presenters/day_presenter_spec.rb`

**Context:**

`StoreHour` has an `open` boolean column and an enum `day_of_week` (0=Sun…6=Sat). `StoreHour.for_date(date)` returns the row for that weekday. A day is closed when `store_hour.open` is false OR a `StoreException` exists with `closed: true` for that date. `StoreException.for_date(date)` returns the row (or nil).

`StoreException` has a boolean `closed` column.

- [ ] **Step 1: Write the failing tests**

Append to `spec/presenters/day_presenter_spec.rb` (before the final `end`):

```ruby
describe ".open_on?(date)" do
  let(:monday) { Date.new(2026, 7, 20) } # wday=1

  before do
    StoreHour.create!(day_of_week: :monday, open: true, opens_at: "09:00", closes_at: "17:00")
  end

  it "returns true when the store hour is open and no closed exception" do
    expect(DayPresenter.open_on?(monday)).to be true
  end

  it "returns false when the store hour is closed" do
    StoreHour.find_by(day_of_week: :monday).update!(open: false)
    expect(DayPresenter.open_on?(monday)).to be false
  end

  it "returns false when a closed StoreException exists for that date" do
    StoreException.create!(date: monday, reason: "Holiday", closed: true)
    expect(DayPresenter.open_on?(monday)).to be false
  end

  it "returns false when no StoreHour row exists for that day" do
    StoreHour.find_by(day_of_week: :monday).destroy
    expect(DayPresenter.open_on?(monday)).to be false
  end
end

describe ".next_open_date(from:)" do
  it "returns nil when no open day is found within 14 days" do
    # No StoreHour rows created → all closed
    expect(DayPresenter.next_open_date(from: Date.new(2026, 7, 20))).to be_nil
  end

  it "returns the next date that is open" do
    wednesday = Date.new(2026, 7, 22) # wday=3
    StoreHour.create!(day_of_week: :wednesday, open: true, opens_at: "09:00", closes_at: "17:00")
    result = DayPresenter.next_open_date(from: Date.new(2026, 7, 20))
    expect(result).to eq(wednesday)
  end

  it "skips dates with a closed StoreException even if the weekday is open" do
    StoreHour.create!(day_of_week: :monday, open: true, opens_at: "09:00", closes_at: "17:00")
    monday = Date.new(2026, 7, 20)
    StoreException.create!(date: monday, reason: "Holiday", closed: true)
    wednesday = Date.new(2026, 7, 22)
    StoreHour.create!(day_of_week: :wednesday, open: true, opens_at: "09:00", closes_at: "17:00")
    result = DayPresenter.next_open_date(from: monday)
    expect(result).to eq(wednesday)
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```
~/.rvm/bin/rvm-shell ruby-4.0.1@massamater -c "bundle exec rspec spec/presenters/day_presenter_spec.rb --format documentation 2>&1 | tail -20"
```

Expected: failures like `undefined method 'open_on?'`.

- [ ] **Step 3: Implement `open_on?` and `next_open_date` in `DayPresenter`**

Add these class methods to `app/presenters/day_presenter.rb`, after the existing `private` section:

```ruby
def self.open_on?(date)
  exc = StoreException.for_date(date)
  return false if exc&.closed?
  hour = StoreHour.for_date(date)
  hour&.open? || false
end

def self.next_open_date(from:)
  (1..14).each do |offset|
    candidate = from + offset
    return candidate if open_on?(candidate)
  end
  nil
end
```

- [ ] **Step 4: Run tests to verify they pass**

```
~/.rvm/bin/rvm-shell ruby-4.0.1@massamater -c "bundle exec rspec spec/presenters/day_presenter_spec.rb --format documentation 2>&1 | tail -20"
```

Expected: all examples pass.

- [ ] **Step 5: Stage (do NOT commit)**

```bash
git add app/presenters/day_presenter.rb spec/presenters/day_presenter_spec.rb
```

---

### Task 2: i18n strings

**Files:**
- Modify: `config/locales/en.yml`
- Modify: `config/locales/pt.yml`

**Context:**

The existing `staff.dashboard` block in `en.yml` ends at `ready_at`. Add three new keys after it. Keep the same 2-space YAML indentation.

- [ ] **Step 1: Add keys to `config/locales/en.yml`**

Inside `staff.dashboard:`, add after `ready_at: "Ready %{time}"`:

```yaml
      closed_today: "The store is closed today."
      next_open: "Next open: %{date}"
      next_open_products_title: "Coming up"
```

- [ ] **Step 2: Add keys to `config/locales/pt.yml`**

Inside `staff.dashboard:`, add after `ready_at: "Pronto às %{time}"`:

```yaml
      closed_today: "A loja está fechada hoje."
      next_open: "Próxima abertura: %{date}"
      next_open_products_title: "A seguir"
```

- [ ] **Step 3: Verify Rails can load the locales**

```
~/.rvm/bin/rvm-shell ruby-4.0.1@massamater -c "bundle exec rails runner 'puts I18n.t(\"staff.dashboard.closed_today\")' 2>&1"
```

Expected: `The store is closed today.`

- [ ] **Step 4: Stage (do NOT commit)**

```bash
git add config/locales/en.yml config/locales/pt.yml
```

---

### Task 3: Controller — set `@next_day` when closed

**Files:**
- Modify: `app/controllers/staff/dashboard_controller.rb`
- Modify: `spec/requests/staff/dashboard_spec.rb`

**Context:**

The controller currently does:
```ruby
def index
  @day = DayPresenter.new(Date.current)
end
```

When today is closed, we also need `@next_day` (a `DayPresenter` for the next open date, or `nil`). The view will use `@next_day` to decide which layout to render.

`spec/requests/staff/dashboard_spec.rb` currently has 2 examples. Add a third for the closed-day case. The spec uses FactoryBot — factories exist at `spec/factories/`. There is no factory for `StoreHour` or `StoreException`; create them inline with `StoreHour.create!` / `StoreException.create!`.

To simulate today being closed: stub `Date.current` to a known Monday (`Date.new(2026, 7, 20)`) and create a `StoreException` marking it closed, plus a `StoreHour` for Wednesday open.

- [ ] **Step 1: Write the failing test**

Append to the `Staff::Dashboard` describe block in `spec/requests/staff/dashboard_spec.rb`:

```ruby
context "when today is closed" do
  before do
    allow(Date).to receive(:current).and_return(Date.new(2026, 7, 20)) # Monday
    StoreException.create!(date: Date.new(2026, 7, 20), reason: "Holiday", closed: true)
    StoreHour.create!(day_of_week: :wednesday, open: true, opens_at: "09:00", closes_at: "17:00")
  end

  it "returns 200 and shows the closed notice" do
    get staff_root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("staff.dashboard.closed_today"))
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```
~/.rvm/bin/rvm-shell ruby-4.0.1@massamater -c "bundle exec rspec spec/requests/staff/dashboard_spec.rb --format documentation 2>&1 | tail -15"
```

Expected: failure — the response body won't include the closed notice yet.

- [ ] **Step 3: Update the controller**

Replace the entire `app/controllers/staff/dashboard_controller.rb` with:

```ruby
module Staff
  class DashboardController < Staff::BaseController
    def index
      today = Date.current
      @day = DayPresenter.new(today)
      unless DayPresenter.open_on?(today)
        next_date = DayPresenter.next_open_date(from: today)
        @next_day = DayPresenter.new(next_date) if next_date
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

```
~/.rvm/bin/rvm-shell ruby-4.0.1@massamater -c "bundle exec rspec spec/requests/staff/dashboard_spec.rb --format documentation 2>&1 | tail -15"
```

Expected: all 3 examples pass (the view change in Task 4 will be needed for this — if it fails because the view doesn't have the closed_today string yet, that's expected; complete Task 4 first then re-run).

- [ ] **Step 5: Stage (do NOT commit)**

```bash
git add app/controllers/staff/dashboard_controller.rb spec/requests/staff/dashboard_spec.rb
```

---

### Task 4: View — closed notice + next-day preview

**Files:**
- Modify: `app/views/staff/dashboard/index.html.erb`

**Context:**

When `@next_day` is set, today is closed. The view should show:
1. A `section-card` with a closed notice: "The store is closed today."
2. A `section-card` with the next open day's products (same product rows as today's normal layout), titled "Coming up" with the next open date as the subtitle.
3. No reservations section (there are none today anyway, and showing next-day reservations isn't useful).

When `@next_day` is nil (no open day found within 14 days), only show the closed notice card with no next-day preview.

When today is open (normal case), render exactly as before — today's products + reservations.

The next-open date subtitle format should be e.g. "Wednesday, Jul 22" — use `I18n.l(date, format: :short_with_day)` (this format key exists in the locales: `"%A, %b %-d"`).

Replace the entire `app/views/staff/dashboard/index.html.erb` with:

```erb
<%# app/views/staff/dashboard/index.html.erb %>
<div class="wrap">

  <div class="topbar">
    <div>
      <div class="pg-title"><%= t("staff.dashboard.title") %></div>
      <div class="pg-sub"><%= I18n.l(Date.current, format: :short_with_day) %></div>
    </div>
  </div>

  <% if @next_day %>
    <%# Closed today — show closed notice + next open day preview %>

    <div class="section-card">
      <div class="section-head">
        <div class="section-head-title"><%= t("staff.dashboard.closed_today") %></div>
      </div>
    </div>

    <% if @next_day %>
      <div class="section-card">
        <div class="section-head">
          <div>
            <div class="section-head-title"><%= t("staff.dashboard.next_open_products_title") %></div>
            <div class="section-head-sub">
              <%= t("staff.dashboard.next_open", date: I18n.l(@next_day.date, format: :short_with_day)) %>
            </div>
          </div>
        </div>

        <% if @next_day.available_products.empty? %>
          <p class="empty-msg"><%= t("staff.dashboard.products_empty") %></p>
        <% else %>
          <% @next_day.available_products.each do |product| %>
            <% total    = @next_day.effective_batch_size(product) %>
            <% reserved = @next_day.reserved_count(product) %>
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
                  <%= t("staff.dashboard.ready_at", time: @next_day.effective_ready_time(product).strftime("%H:%M")) %>
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
    <% end %>

  <% else %>
    <%# Normal open day — products + reservations %>

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

  <% end %>

</div>
```

Note: `@next_day.date` requires exposing `@date` from `DayPresenter`. Add a reader to the presenter:

In `app/presenters/day_presenter.rb`, add `attr_reader :date` after the class declaration:

```ruby
class DayPresenter
  attr_reader :date

  def initialize(date)
    ...
```

- [ ] **Step 1: Add `attr_reader :date` to `DayPresenter`**

Edit `app/presenters/day_presenter.rb` line 1–2:

```ruby
class DayPresenter
  attr_reader :date

  def initialize(date)
    @date       = date
```

- [ ] **Step 2: Replace the view**

Write the full view content shown above to `app/views/staff/dashboard/index.html.erb`.

- [ ] **Step 3: Run all presenter and dashboard specs**

```
~/.rvm/bin/rvm-shell ruby-4.0.1@massamater -c "bundle exec rspec spec/presenters/day_presenter_spec.rb spec/requests/staff/dashboard_spec.rb --format documentation 2>&1 | tail -25"
```

Expected: all examples pass.

- [ ] **Step 4: Stage (do NOT commit)**

```bash
git add app/presenters/day_presenter.rb app/views/staff/dashboard/index.html.erb
```

---

### Task 5: Deploy + smoke test

**Files:** None (deployment only)

- [ ] **Step 1: Run the full test suite and confirm only pre-existing failures**

```
~/.rvm/bin/rvm-shell ruby-4.0.1@massamater -c "bundle exec rspec --format progress 2>&1 | tail -10"
```

Expected: 2 pre-existing failures (`user_spec.rb:15` phone format, `store_hours_spec.rb:18` snapshot). Zero new failures.

- [ ] **Step 2: Tell the user to commit and deploy**

The user commits manually. Provide the commit command:

```bash
git commit -m "feat: show closed notice and next-open preview on today page

- DayPresenter.open_on? checks StoreHour + StoreException for a date
- DayPresenter.next_open_date walks forward up to 14 days
- DashboardController sets @next_day when today is closed
- View renders closed notice + next-day product preview when closed

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

Then: `fly deploy`

- [ ] **Step 3: Report DONE**

Report status DONE once the test suite confirms zero new failures.
