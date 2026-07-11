# Store Hours Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Staff — Store Hours screen (spec §4.6): a single page where staff can edit the weekly recurring schedule and manage one-off date exceptions.

**Architecture:** Two sub-resources under `staff/store_hours` — the weekly schedule is a bulk-update of all 7 `StoreHour` rows (a single form, save-all), and exceptions are a nested resource (`staff/store_exceptions`) supporting create and destroy. All writes go through standard Rails controllers with Turbo for the delete action. No JavaScript required beyond default Turbo/Stimulus.

**Tech Stack:** Rails 8.1.3, Turbo (default Rails), ERB, i18n (pt/en), RSpec request specs.

---

## File Map

| File | Purpose |
|---|---|
| `app/controllers/staff/store_hours_controller.rb` | `edit` + `update` for weekly schedule |
| `app/controllers/staff/store_exceptions_controller.rb` | `create` + `destroy` for exceptions |
| `app/views/staff/store_hours/edit.html.erb` | Combined page: weekly schedule + exceptions |
| `config/routes.rb` | Add staff routes |
| `config/locales/en.yml` | Add store_hours i18n keys |
| `config/locales/pt.yml` | Add store_hours i18n keys |
| `spec/requests/staff/store_hours_spec.rb` | Request specs |
| `spec/requests/staff/store_exceptions_spec.rb` | Request specs |

---

### Task 1: Routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Add store hours and exceptions routes inside the staff namespace**

Open `config/routes.rb` and replace the staff namespace block:

```ruby
Rails.application.routes.draw do
  root "pages#home"

  get    "/login",  to: "sessions#new",     as: :login
  post   "/login",  to: "sessions#create"
  delete "/logout", to: "sessions#destroy", as: :logout

  patch "/locale", to: "locales#update", as: :locale

  namespace :staff do
    root "dashboard#index"
    resource  :store_hours,    only: [:edit, :update]
    resources :store_exceptions, only: [:create, :destroy]
  end
end
```

- [ ] **Step 2: Verify routes are correct**

```bash
bin/rails routes | grep store
```

Expected output includes:
```
edit_staff_store_hours GET    /staff/store_hours/edit
     staff_store_hours PATCH  /staff/store_hours
staff_store_exceptions POST   /staff/store_exceptions
 staff_store_exception DELETE /staff/store_exceptions/:id
```

- [ ] **Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "feat(store-hours): add staff routes for store hours and exceptions"
```

---

### Task 2: i18n strings

**Files:**
- Modify: `config/locales/en.yml`
- Modify: `config/locales/pt.yml`

- [ ] **Step 1: Add English strings**

Add to `config/locales/en.yml` under the `en:` root (after the existing `store:` key):

```yaml
  store_hours:
    title: "Store hours"
    subtitle: "Weekly schedule and one-off exceptions"
    save: "Save"
    reservation_window_note: "Reservations accepted up to <strong>7 days</strong> ahead. Closed days don't appear in the reservation form."
    weekly:
      title: "Weekly schedule"
      subtitle: "Repeats automatically every week"
      to: "to"
      closed_pill: "Closed"
    exceptions:
      title: "One-off exceptions"
      subtitle: "Holidays, emergencies, or different hours on a specific date"
      closed_tag: "Closed"
      add_placeholder_reason: "Reason (e.g. family emergency…)"
      type_closed: "Closed"
      type_different_hours: "Different hours"
      add_button: "+ Add"
      delete_button: "Delete"
      opens_at_label: "Opens at"
      closes_at_label: "Closes at"
```

- [ ] **Step 2: Add Portuguese strings**

Add to `config/locales/pt.yml` under the `pt:` root (after the existing `store:` key):

```yaml
  store_hours:
    title: "Horário da loja"
    subtitle: "Horário semanal e exceções pontuais"
    save: "Guardar"
    reservation_window_note: "Reservas aceites até <strong>7 dias</strong> de antecedência. Os dias fechados não aparecem no formulário de reserva."
    weekly:
      title: "Horário semanal"
      subtitle: "Repete automaticamente todas as semanas"
      to: "às"
      closed_pill: "Fechado"
    exceptions:
      title: "Exceções pontuais"
      subtitle: "Feriados, emergências ou horário diferente numa data específica"
      closed_tag: "Fechado"
      add_placeholder_reason: "Motivo (ex: emergência familiar…)"
      type_closed: "Fechado"
      type_different_hours: "Horário diferente"
      add_button: "+ Adicionar"
      delete_button: "Eliminar"
      opens_at_label: "Abre às"
      closes_at_label: "Fecha às"
```

- [ ] **Step 3: Commit**

```bash
git add config/locales/en.yml config/locales/pt.yml
git commit -m "feat(store-hours): add i18n strings for store hours screen"
```

---

### Task 3: StoreHoursController + request spec

**Files:**
- Create: `app/controllers/staff/store_hours_controller.rb`
- Create: `spec/requests/staff/store_hours_spec.rb`

- [ ] **Step 1: Write the failing request spec**

Create `spec/requests/staff/store_hours_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Staff::StoreHours", type: :request do
  let(:staff) { create(:user, :staff, phone: "+351910000099") }

  before { post login_path, params: { phone: staff.phone, password: "password" } }

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
```

- [ ] **Step 2: Run spec to see it fail**

```bash
bundle exec rspec spec/requests/staff/store_hours_spec.rb
```

Expected: failures (controller doesn't exist yet, seeds not run in test env).

- [ ] **Step 3: Write the controller**

Create `app/controllers/staff/store_hours_controller.rb`:

```ruby
class Staff::StoreHoursController < Staff::BaseController
  def edit
    @store_hours = StoreHour.order(:day_of_week)
    @exceptions  = StoreException.where("date >= ?", Date.current).order(:date)
    @new_exception = StoreException.new
  end

  def update
    (params[:store_hours] || {}).each do |id, attrs|
      hour = StoreHour.find(id)
      open = attrs[:open] == "1"
      if open
        hour.update!(open: true, opens_at: attrs[:opens_at], closes_at: attrs[:closes_at])
      else
        hour.update!(open: false, opens_at: attrs[:opens_at], closes_at: attrs[:closes_at])
      end
    end
    redirect_to edit_staff_store_hours_path, notice: t("store_hours.saved")
  end
end
```

Note: when a day is toggled closed in the HTML form, the `open` checkbox is unchecked and the `open` param is absent from the submission. The controller treats missing `open` param as `false`. Times are preserved even for closed days (kept in the DB for when the day is re-opened).

- [ ] **Step 4: Add missing i18n key**

Add `saved: "Saved."` / `saved: "Guardado."` to `store_hours:` in both locale files.

en.yml — add inside `store_hours:`:
```yaml
    saved: "Saved."
```

pt.yml — add inside `store_hours:`:
```yaml
    saved: "Guardado."
```

- [ ] **Step 5: Run spec again**

The spec requires seeded `StoreHour` rows (days tuesday–saturday must exist). Add a `before` block to seed them in the spec:

Update `spec/requests/staff/store_hours_spec.rb` — add after the `before` login block:

```ruby
  before do
    post login_path, params: { phone: staff.phone, password: "password" }
    # Seed the 7 StoreHour rows if not present
    %i[sunday monday tuesday wednesday thursday friday saturday].each_with_index do |day, i|
      StoreHour.find_or_create_by!(day_of_week: i) do |sh|
        sh.open      = day.in?(%i[tuesday wednesday thursday friday saturday])
        sh.opens_at  = "08:00"
        sh.closes_at = "18:00"
      end
    end
  end
```

Then run:

```bash
bundle exec rspec spec/requests/staff/store_hours_spec.rb
```

Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/staff/store_hours_controller.rb \
        spec/requests/staff/store_hours_spec.rb \
        config/locales/en.yml config/locales/pt.yml
git commit -m "feat(store-hours): StoreHoursController with edit + update"
```

---

### Task 4: StoreExceptionsController + request spec

**Files:**
- Create: `app/controllers/staff/store_exceptions_controller.rb`
- Create: `spec/requests/staff/store_exceptions_spec.rb`

- [ ] **Step 1: Write the failing request spec**

Create `spec/requests/staff/store_exceptions_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Staff::StoreExceptions", type: :request do
  let(:staff) { create(:user, :staff, phone: "+351910000098") }

  before { post login_path, params: { phone: staff.phone, password: "password" } }

  describe "POST /staff/store_exceptions" do
    it "creates a closed exception and redirects" do
      expect {
        post staff_store_exceptions_path, params: {
          store_exception: {
            date:   "2026-12-25",
            reason: "Christmas",
            closed: "1"
          }
        }
      }.to change(StoreException, :count).by(1)
      expect(response).to redirect_to(edit_staff_store_hours_path)
      exc = StoreException.last
      expect(exc.closed).to be true
      expect(exc.reason).to eq("Christmas")
    end

    it "creates a different-hours exception with times" do
      post staff_store_exceptions_path, params: {
        store_exception: {
          date:      "2026-12-26",
          reason:    "Special hours",
          closed:    "0",
          opens_at:  "10:00",
          closes_at: "14:00"
        }
      }
      exc = StoreException.last
      expect(exc.closed).to be false
      expect(exc.opens_at.strftime("%H:%M")).to eq("10:00")
    end

    it "does not create with missing reason and re-renders edit" do
      expect {
        post staff_store_exceptions_path, params: {
          store_exception: { date: "2026-12-27", reason: "", closed: "1" }
        }
      }.not_to change(StoreException, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /staff/store_exceptions/:id" do
    it "destroys the exception and redirects" do
      exc = create(:store_exception, date: Date.new(2026, 12, 28))
      expect {
        delete staff_store_exception_path(exc)
      }.to change(StoreException, :count).by(-1)
      expect(response).to redirect_to(edit_staff_store_hours_path)
    end
  end
end
```

- [ ] **Step 2: Run spec to see it fail**

```bash
bundle exec rspec spec/requests/staff/store_exceptions_spec.rb
```

- [ ] **Step 3: Write the controller**

Create `app/controllers/staff/store_exceptions_controller.rb`:

```ruby
class Staff::StoreExceptionsController < Staff::BaseController
  def create
    @exception = StoreException.new(exception_params)
    if @exception.save
      redirect_to edit_staff_store_hours_path, notice: t("store_hours.exceptions.added")
    else
      @store_hours   = StoreHour.order(:day_of_week)
      @exceptions    = StoreException.where("date >= ?", Date.current).order(:date)
      @new_exception = @exception
      render "staff/store_hours/edit", status: :unprocessable_entity
    end
  end

  def destroy
    StoreException.find(params[:id]).destroy
    redirect_to edit_staff_store_hours_path, notice: t("store_hours.exceptions.removed")
  end

  private

  def exception_params
    p = params.require(:store_exception).permit(:date, :reason, :closed, :opens_at, :closes_at)
    p[:closed] = p[:closed] == "1"
    p
  end
end
```

- [ ] **Step 4: Add missing i18n keys**

en.yml — add inside `store_hours.exceptions:`:
```yaml
      added: "Exception added."
      removed: "Exception removed."
```

pt.yml — add inside `store_hours.exceptions:`:
```yaml
      added: "Exceção adicionada."
      removed: "Exceção removida."
```

- [ ] **Step 5: Run spec**

```bash
bundle exec rspec spec/requests/staff/store_exceptions_spec.rb
```

Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/staff/store_exceptions_controller.rb \
        spec/requests/staff/store_exceptions_spec.rb \
        config/locales/en.yml config/locales/pt.yml
git commit -m "feat(store-hours): StoreExceptionsController with create + destroy"
```

---

### Task 5: Store Hours view

**Files:**
- Create: `app/views/staff/store_hours/edit.html.erb`

- [ ] **Step 1: Create the view directory**

```bash
mkdir -p app/views/staff/store_hours
```

- [ ] **Step 2: Create `app/views/staff/store_hours/edit.html.erb`**

```erb
<div class="wrap">
  <div class="topbar">
    <div>
      <div class="pg-title"><%= t("store_hours.title") %></div>
      <div class="pg-sub"><%= t("store_hours.subtitle") %></div>
    </div>
  </div>

  <div class="info-strip">
    📅 <%= t("store_hours.reservation_window_note").html_safe %>
  </div>

  <%# Weekly schedule — one form for all 7 days %>
  <%= form_with url: staff_store_hours_path, method: :patch do |f| %>
    <div class="section-card">
      <div class="section-head">
        <div class="section-head-title"><%= t("store_hours.weekly.title") %></div>
        <div class="section-head-sub"><%= t("store_hours.weekly.subtitle") %></div>
      </div>

      <% @store_hours.each do |sh| %>
        <% day_name = I18n.t("date.day_names")[sh.day_of_week_before_type_cast] %>
        <div class="day-row <%= 'closed-row' unless sh.open? %>">
          <div class="day-name"><%= day_name %></div>

          <label class="toggle <%= 'off' unless sh.open? %>">
            <%= check_box_tag "store_hours[#{sh.id}][open]", "1", sh.open?,
                              id: "open_#{sh.id}", class: "sr-only" %>
            <div class="knob"></div>
          </label>

          <div class="time-range">
            <%= time_field_tag "store_hours[#{sh.id}][opens_at]",
                               sh.opens_at&.strftime("%H:%M"),
                               class: "time-in",
                               disabled: !sh.open? %>
            <span class="sep"><%= t("store_hours.weekly.to") %></span>
            <%= time_field_tag "store_hours[#{sh.id}][closes_at]",
                               sh.closes_at&.strftime("%H:%M"),
                               class: "time-in",
                               disabled: !sh.open? %>
            <% unless sh.open? %>
              <span class="closed-pill"><%= t("store_hours.weekly.closed_pill") %></span>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>

    <div style="text-align:right;margin-bottom:14px">
      <%= f.submit t("store_hours.save"), class: "save-btn" %>
    </div>
  <% end %>

  <%# Exceptions %>
  <div class="section-card">
    <div class="section-head">
      <div class="section-head-title"><%= t("store_hours.exceptions.title") %></div>
      <div class="section-head-sub"><%= t("store_hours.exceptions.subtitle") %></div>
    </div>

    <% @exceptions.each do |exc| %>
      <div class="exc-row">
        <div class="exc-date">
          <%= exc.date.strftime("%b %-d, %Y") %>
          <span class="exc-weekday"><%= I18n.t("date.day_names")[exc.date.wday] %></span>
        </div>
        <div class="exc-reason"><%= exc.reason %></div>
        <% if exc.closed? %>
          <span class="closed-tag"><%= t("store_hours.exceptions.closed_tag") %></span>
        <% else %>
          <span class="hours-tag">
            <%= exc.opens_at.strftime("%H:%M") %> – <%= exc.closes_at.strftime("%H:%M") %>
          </span>
        <% end %>
        <%= button_to t("store_hours.exceptions.delete_button"),
                      staff_store_exception_path(exc),
                      method: :delete,
                      class: "del-btn",
                      form: { data: { turbo_confirm: "Delete this exception?" } } %>
      </div>
    <% end %>

    <%# Add exception form %>
    <%= form_with model: @new_exception,
                  url: staff_store_exceptions_path,
                  data: { controller: "exception-form" } do |f| %>
      <div class="add-exc-row">
        <%= f.date_field :date, class: "date-in" %>
        <%= f.text_field :reason,
                         placeholder: t("store_hours.exceptions.add_placeholder_reason"),
                         class: "reason-in" %>
        <div class="type-sel">
          <label class="type-opt <%= 'sel' if @new_exception.closed? || @new_exception.new_record? %>">
            <%= f.radio_button :closed, "1", checked: @new_exception.new_record? %>
            <%= t("store_hours.exceptions.type_closed") %>
          </label>
          <label class="type-opt <%= 'sel' unless @new_exception.closed? || @new_exception.new_record? %>">
            <%= f.radio_button :closed, "0" %>
            <%= t("store_hours.exceptions.type_different_hours") %>
          </label>
        </div>
        <div class="different-hours-fields" style="display:none">
          <%= f.label :opens_at,  t("store_hours.exceptions.opens_at_label") %>
          <%= f.time_field :opens_at,  class: "time-in" %>
          <%= f.label :closes_at, t("store_hours.exceptions.closes_at_label") %>
          <%= f.time_field :closes_at, class: "time-in" %>
        </div>
        <%= f.submit t("store_hours.exceptions.add_button"), class: "add-btn-sm" %>
      </div>
      <% if @new_exception.errors.any? %>
        <div class="form-errors" style="padding:8px 16px;color:#c62828;font-size:13px">
          <%= @new_exception.errors.full_messages.to_sentence %>
        </div>
      <% end %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 3: Update the staff layout nav link for Settings**

In `app/views/layouts/staff.html.erb`, replace the `"#"` placeholder for settings with the real path:

Change:
```erb
    <%= link_to t("staff.nav.settings"),  "#" %>
```
To:
```erb
    <%= link_to t("staff.nav.settings"),  edit_staff_store_hours_path %>
```

- [ ] **Step 4: Verify the page renders**

```bash
bundle exec rspec spec/requests/staff/store_hours_spec.rb spec/requests/staff/store_exceptions_spec.rb
```

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add app/views/staff/store_hours/edit.html.erb \
        app/views/layouts/staff.html.erb
git commit -m "feat(store-hours): store hours edit view and nav link"
```

---

### Task 6: Toggle interactivity (Stimulus)

The open/closed toggle needs JavaScript to: (a) visually flip the toggle, (b) enable/disable the time inputs, (c) show/hide "Closed" pill, and (d) show/hide the "Different hours" time fields in the add-exception form.

**Files:**
- Create: `app/javascript/controllers/store_hours_controller.js`
- Create: `app/javascript/controllers/exception_form_controller.js`

- [ ] **Step 1: Create the store_hours Stimulus controller**

Create `app/javascript/controllers/store_hours_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "opensAt", "closesAt", "closedPill"]

  toggle(event) {
    const row    = event.currentTarget.closest(".day-row")
    const isOpen = event.currentTarget.checked
    row.classList.toggle("closed-row", !isOpen)
    row.querySelectorAll(".time-in").forEach(el => el.disabled = !isOpen)
    const pill = row.querySelector(".closed-pill")
    if (pill) pill.style.display = isOpen ? "none" : ""
    const toggle = row.querySelector(".toggle")
    toggle.classList.toggle("off", !isOpen)
  }
}
```

- [ ] **Step 2: Wire Stimulus to the weekly schedule rows**

Update the toggle label in `edit.html.erb` — add `data-action`:

Replace:
```erb
          <label class="toggle <%= 'off' unless sh.open? %>">
            <%= check_box_tag "store_hours[#{sh.id}][open]", "1", sh.open?,
                              id: "open_#{sh.id}", class: "sr-only" %>
            <div class="knob"></div>
          </label>
```

With:
```erb
          <label class="toggle <%= 'off' unless sh.open? %>">
            <%= check_box_tag "store_hours[#{sh.id}][open]", "1", sh.open?,
                              id: "open_#{sh.id}", class: "sr-only",
                              data: { action: "change->store-hours#toggle" } %>
            <div class="knob"></div>
          </label>
```

And add `data-controller="store-hours"` to the `<div class="section-card">` wrapping the weekly schedule:

Replace:
```erb
    <div class="section-card">
      <div class="section-head">
        <div class="section-head-title"><%= t("store_hours.weekly.title") %></div>
```

With:
```erb
    <div class="section-card" data-controller="store-hours">
      <div class="section-head">
        <div class="section-head-title"><%= t("store_hours.weekly.title") %></div>
```

- [ ] **Step 3: Create the exception_form Stimulus controller**

Create `app/javascript/controllers/exception_form_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["differentHoursFields"]

  connect() {
    this.updateFields()
  }

  updateFields() {
    const isDifferentHours = this.element.querySelector('input[name*="closed"][value="0"]')?.checked
    this.differentHoursFieldsTarget.style.display = isDifferentHours ? "" : "none"
  }

  typeChanged() {
    this.updateFields()
  }
}
```

- [ ] **Step 4: Wire Stimulus to the add-exception form**

In `edit.html.erb`, update the form and different-hours div:

Replace:
```erb
    <%= form_with model: @new_exception,
                  url: staff_store_exceptions_path,
                  data: { controller: "exception-form" } do |f| %>
```

With:
```erb
    <%= form_with model: @new_exception,
                  url: staff_store_exceptions_path,
                  data: { controller: "exception-form",
                          action: "change->exception-form#typeChanged" } do |f| %>
```

Replace:
```erb
        <div class="different-hours-fields" style="display:none">
```

With:
```erb
        <div class="different-hours-fields"
             data-exception-form-target="differentHoursFields"
             style="display:none">
```

- [ ] **Step 5: Run full spec suite**

```bash
bundle exec rspec
```

Expected: all previously passing specs still pass. No new failures.

- [ ] **Step 6: Commit**

```bash
git add app/javascript/controllers/store_hours_controller.js \
        app/javascript/controllers/exception_form_controller.js \
        app/views/staff/store_hours/edit.html.erb
git commit -m "feat(store-hours): Stimulus controllers for toggle and exception type"
```

---

### Task 7: CSS styles

The store hours screen needs styles that match the mockup. Add them to the application stylesheet rather than inline.

**Files:**
- Modify: `app/assets/stylesheets/application.css` (or whichever stylesheet exists)

- [ ] **Step 1: Check which stylesheet file exists**

```bash
ls app/assets/stylesheets/
```

- [ ] **Step 2: Append store-hours styles**

Add to the end of the existing stylesheet:

```css
/* ── Store Hours ─────────────────────────────────── */
.wrap           { background:#f4efe7;border-radius:14px;padding:16px }
.topbar         { display:flex;align-items:center;justify-content:space-between;margin-bottom:16px;flex-wrap:wrap;gap:10px }
.pg-title       { font-size:20px;font-weight:700;color:#2b2b2b }
.pg-sub         { font-size:13px;color:#9b8a6e;margin-top:2px }
.save-btn       { background:#7a4f2b;color:#fff;border:none;padding:11px 22px;border-radius:10px;font-size:14px;font-weight:700;cursor:pointer }
.info-strip     { display:flex;align-items:center;gap:8px;background:#faf3e9;border-radius:8px;padding:10px 14px;font-size:13px;color:#7a4f2b;margin-bottom:14px }
.section-card   { background:#fff;border-radius:12px;border:1px solid #e3d9c8;margin-bottom:14px;overflow:hidden }
.section-head   { padding:13px 16px;border-bottom:1px solid #ede5d8 }
.section-head-title { font-size:14px;font-weight:700;color:#2b2b2b }
.section-head-sub   { font-size:12px;color:#9b8a6e;margin-top:2px }
.day-row        { display:flex;align-items:center;gap:14px;padding:12px 16px;border-bottom:1px solid #f0e9dd }
.day-row:last-child { border-bottom:none }
.day-row.closed-row { background:#fafaf8 }
.day-name       { font-size:14px;font-weight:700;color:#2b2b2b;width:96px;flex:0 0 auto }
.day-row.closed-row .day-name { color:#b0a898 }
.toggle         { width:40px;height:22px;border-radius:11px;background:#7a4f2b;position:relative;cursor:pointer;flex:0 0 auto;display:inline-block }
.toggle .knob   { width:16px;height:16px;border-radius:50%;background:#fff;position:absolute;top:3px;right:3px }
.toggle.off     { background:#d0c8bc }
.toggle.off .knob { left:3px;right:auto }
.sr-only        { position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);border:0 }
.time-range     { display:flex;align-items:center;gap:8px }
.time-in        { border:2px solid #e3d9c8;border-radius:7px;padding:7px 9px;font-size:13px;font-weight:700;color:#2b2b2b;background:#fdfbf7;width:78px;text-align:center }
.time-in:disabled { color:#c0b8ae;background:#f5f2ee;cursor:not-allowed }
.sep            { font-size:12px;color:#b08c5e;font-weight:700 }
.closed-pill    { font-size:12px;font-weight:700;color:#9b8a6e;background:#f0ede8;padding:5px 12px;border-radius:20px }
.exc-row        { display:flex;align-items:center;gap:12px;padding:12px 16px;border-bottom:1px solid #f0e9dd }
.exc-row:last-child { border-bottom:none }
.exc-date       { font-size:14px;font-weight:700;color:#2b2b2b;width:140px;flex:0 0 auto }
.exc-weekday    { font-size:11px;color:#9b8a6e;font-weight:500;display:block;margin-top:1px }
.exc-reason     { flex:1;font-size:13px;color:#555;font-style:italic }
.closed-tag     { font-size:12px;font-weight:700;color:#c62828;background:#fdecea;padding:4px 10px;border-radius:6px }
.hours-tag      { font-size:12px;font-weight:700;color:#7a4f2b;background:#faf3e9;padding:4px 10px;border-radius:6px }
.del-btn        { width:30px;height:30px;border-radius:6px;border:1px solid #e3d9c8;background:#fff;color:#c62828;cursor:pointer;font-size:15px;display:flex;align-items:center;justify-content:center;flex:0 0 auto }
.add-exc-row    { display:flex;align-items:center;gap:10px;padding:12px 16px;flex-wrap:wrap;background:#fdfbf7;border-top:1px solid #ede5d8 }
.date-in        { border:2px solid #e3d9c8;border-radius:7px;padding:8px 10px;font-size:13px;color:#2b2b2b;background:#fff }
.reason-in      { border:2px solid #e3d9c8;border-radius:7px;padding:8px 10px;font-size:13px;color:#2b2b2b;background:#fff;flex:1;min-width:140px }
.type-sel       { display:flex;gap:6px }
.type-opt       { padding:7px 12px;border:2px solid #e3d9c8;border-radius:7px;font-size:12px;font-weight:700;cursor:pointer;color:#6b5d45 }
.type-opt.sel   { border-color:#c62828;background:#fdecea;color:#c62828 }
.type-opt input { display:none }
.add-btn-sm     { background:#7a4f2b;color:#fff;border:none;padding:8px 14px;border-radius:7px;font-size:13px;font-weight:700;cursor:pointer;white-space:nowrap }
.form-errors    { padding:8px 16px;color:#c62828;font-size:13px }
```

- [ ] **Step 3: Run specs**

```bash
bundle exec rspec
```

Expected: all green.

- [ ] **Step 4: Commit**

```bash
git add app/assets/stylesheets/
git commit -m "feat(store-hours): add CSS styles matching mockup"
```

---

### Task 8: Deploy + smoke test

- [ ] **Step 1: Deploy to Fly.io**

```bash
fly deploy
```

- [ ] **Step 2: Seed the database (if not already done)**

```bash
fly ssh console -C "bin/rails db:seed"
```

- [ ] **Step 3: Open the store hours page and verify**

```bash
fly open /login
```

Log in with `+351912000001` / `password`, click **Settings** in the nav, verify:
- All 7 days appear with their current open/closed state
- Toggling a day enables/disables the time inputs
- Saving redirects back with a success flash
- Adding a closed exception appears in the list
- Deleting an exception removes it

- [ ] **Step 4: Commit if any fixes were needed, then tag**

```bash
git add -A
git commit -m "fix(store-hours): <describe any fixes>"
```

---

## Self-Review

**Spec coverage:**
- §4.6 Weekly schedule — edit + save: ✅ Task 3
- §4.6 Toggle open/closed, time inputs disabled when closed: ✅ Task 6 (Stimulus)
- §4.6 One-off exceptions — list upcoming only (past hidden): ✅ Task 3 controller (`date >= Date.current`)
- §4.6 Exception add form (date, reason, type toggle, times when different hours): ✅ Tasks 4 + 5
- §4.6 Exception delete: ✅ Task 4
- §4.6 Reservation window note (7 days hardcoded): ✅ Task 5 view
- §4.6 Saves to `store_hours` / `store_exceptions`: ✅ Tasks 3 + 4

**Placeholder scan:** No TBD, TODO, or vague steps. All code is written out in full.

**Type consistency:** `StoreHour` / `StoreException` match Foundation plan models exactly. Route helpers (`edit_staff_store_hours_path`, `staff_store_exceptions_path`, `staff_store_exception_path`) are consistent across controller, view, and spec.
