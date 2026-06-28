# Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bootstrap the Rails application with all database tables, models, staff authentication, i18n scaffolding, a minimal layout shell, seed data, and a working Fly.io deployment.

**Architecture:** Server-rendered Rails 8 app with SQLite on a persistent Fly.io volume. All models and business-rule helpers live here; feature plans (screens 4.1–4.8) build on top. No background jobs, no mailer, no ActionCable in v1.

**Tech Stack:** Ruby 4.0.1 (RVM), Ruby on Rails 8, SQLite3, Active Storage, bcrypt (`has_secure_password`), RSpec + FactoryBot + Shoulda-matchers, Fly.io.

---

## File Map

| File | Purpose |
|---|---|
| `.ruby-version` | Pins Ruby version for RVM and RubyMine |
| `.ruby-gemset` | Pins RVM gemset name for auto-switch |
| `Gemfile` | Add bcrypt, rspec-rails, factory_bot_rails, shoulda-matchers, faker |
| `config/database.yml` | Production DB path → `/data/db/production.sqlite3` |
| `config/application.rb` | i18n default `:pt`, available `[:pt, :en]` |
| `config/routes.rb` | Sessions, locale switcher, staff namespace, roots |
| `db/migrate/*` | One migration per table (8 migrations) |
| `app/models/user.rb` | Phone-identified user, has_secure_password, staff? helper |
| `app/models/product.rb` | Catalogue item, Active Storage attachments, display_name |
| `app/models/product_schedule_day.rb` | Which days a product is normally baked |
| `app/models/store_hour.rb` | Weekly recurring schedule (7 rows) |
| `app/models/store_exception.rb` | One-off date overrides |
| `app/models/daily_inventory.rb` | Per-date overrides; effective_ready_time |
| `app/models/reservation.rb` | A customer order; scopes, cancellable? |
| `app/models/reservation_item.rb` | Line item for a reservation |
| `app/controllers/application_controller.rb` | Locale, staff auth helpers |
| `app/controllers/sessions_controller.rb` | Staff login/logout |
| `app/controllers/locales_controller.rb` | PT/EN toggle |
| `app/controllers/staff/base_controller.rb` | `before_action :require_staff!` |
| `app/controllers/staff/dashboard_controller.rb` | Placeholder index |
| `app/views/layouts/application.html.erb` | Base HTML shell |
| `app/views/layouts/staff.html.erb` | Staff shell with nav |
| `app/views/sessions/new.html.erb` | Login form |
| `app/views/staff/dashboard/index.html.erb` | Placeholder |
| `config/locales/pt.yml` | Portuguese strings |
| `config/locales/en.yml` | English strings |
| `db/seeds.rb` | Staff user, store hours, sample products |
| `fly.toml` | Fly.io app config with volume mount |
| `spec/rails_helper.rb` | RSpec Rails config, Shoulda-matchers |
| `spec/factories/*.rb` | One factory per model |
| `spec/models/*_spec.rb` | Unit tests for all models |
| `spec/requests/sessions_spec.rb` | Staff login/logout flow |

---

### Task 1: Create Rails application

**Files:**
- Create: `.ruby-version`
- Create: `.ruby-gemset`
- Create: (entire Rails app in current directory)

- [ ] **Step 1: Create RVM config files**

Run from `/Users/rogergraves/workspace/massamater`:

```bash
echo "4.0.1" > .ruby-version
echo "massamater" > .ruby-gemset
```

- [ ] **Step 2: Re-enter the directory so RVM picks up the files**

```bash
cd .. && cd massamater
```

RVM should print something like: `Using ruby-4.0.1 with gemset massamater`. If the gemset doesn't exist yet, RVM will offer to create it — accept, or create it manually:

```bash
rvm gemset create massamater
rvm use 4.0.1@massamater
```

- [ ] **Step 3: Verify RVM is using the right Ruby and gemset**

```bash
rvm current
```

Expected: `ruby-4.0.1@massamater`

- [ ] **Step 4: Install Bundler and Rails into the gemset**

```bash
gem install bundler rails
```

- [ ] **Step 5: Confirm Rails version**

```bash
rails --version
```

Expected: `Rails 8.x.x`.

- [ ] **Step 6: Generate the app in the current directory**

```bash
rails new . \
  --database=sqlite3 \
  --skip-test \
  --skip-action-mailer \
  --skip-action-mailbox \
  --skip-action-cable \
  --skip-action-text \
  --skip-solid
```

When prompted about existing files (`README.md`, `.gitignore`), choose **Y** (overwrite). The `docs/`, `.claude/`, `.ruby-version`, and `.ruby-gemset` files are untouched by Rails.

- [ ] **Step 7: Add JetBrains entries to .gitignore**

Rails generates a `.gitignore`. Open it and append the following at the bottom:

```gitignore
# JetBrains / RubyMine
.idea/
*.iml
*.iws
*.ipr
out/
.idea_modules/
```

- [ ] **Step 8: Verify the app boots**

```bash
bin/rails server
```

Open `http://localhost:3000`. Expected: Rails welcome page. Stop the server.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "chore: bootstrap Rails 8 application with RVM gemset and JetBrains gitignore"
```

---

### Task 2: Configure Gemfile + RSpec

**Files:**
- Modify: `Gemfile`
- Create: `spec/rails_helper.rb`, `spec/spec_helper.rb`, `spec/support/factory_bot.rb`, `spec/support/shoulda_matchers.rb`

- [ ] **Step 1: Update Gemfile**

Uncomment `gem "bcrypt"` if present (it is in the Rails default Gemfile, just commented out). Add the test/dev gems:

```ruby
# In Gemfile — uncomment:
gem "bcrypt", "~> 3.1.7"

group :development, :test do
  gem "rspec-rails", "~> 7.0"
  gem "factory_bot_rails"
  gem "shoulda-matchers", "~> 6.0"
  gem "faker"
end
```

- [ ] **Step 2: Install**

```bash
bundle install
```

- [ ] **Step 3: Install RSpec**

```bash
bin/rails generate rspec:install
```

This creates `spec/`, `spec/rails_helper.rb`, `spec/spec_helper.rb`, `.rspec`.

- [ ] **Step 4: Configure Shoulda-matchers**

Add to the bottom of `spec/rails_helper.rb`:

```ruby
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
```

- [ ] **Step 5: Configure FactoryBot**

Create `spec/support/factory_bot.rb`:

```ruby
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
```

Add to `spec/rails_helper.rb` (inside the `RSpec.configure` block, near the top):

```ruby
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }
```

- [ ] **Step 6: Verify RSpec runs**

```bash
bundle exec rspec
```

Expected: `0 examples, 0 failures`.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: add RSpec, FactoryBot, Shoulda-matchers"
```

---

### Task 3: Users table + model

**Files:**
- Create: `db/migrate/*_create_users.rb`
- Create: `app/models/user.rb`
- Create: `spec/factories/users.rb`
- Create: `spec/models/user_spec.rb`

- [ ] **Step 1: Generate migration**

```bash
bin/rails generate migration CreateUsers \
  phone:string:uniq \
  name:string \
  contact_channel:integer \
  password_digest:string
```

- [ ] **Step 2: Edit migration to add constraints and defaults**

Open the generated migration and make it match:

```ruby
class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string  :phone,           null: false
      t.string  :name,            null: false
      t.integer :contact_channel, null: false, default: 0
      t.string  :password_digest

      t.timestamps
    end

    add_index :users, :phone, unique: true
  end
end
```

- [ ] **Step 3: Write the failing model spec**

Create `spec/models/user_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:reservations).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:phone) }
    it { is_expected.to validate_uniqueness_of(:phone).case_insensitive }
    it { is_expected.to validate_presence_of(:name) }

    it "requires E.164 phone format" do
      user = build(:user, phone: "912345678")
      expect(user).not_to be_valid
      expect(user.errors[:phone]).to include("must be in E.164 format (+country code)")
    end

    it "accepts valid E.164 phone" do
      user = build(:user, phone: "+351912345678")
      expect(user).to be_valid
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:contact_channel).with_values(sms: 0, whatsapp: 1) }
  end

  describe "#staff?" do
    it "returns true when password_digest is present" do
      user = build(:user, password: "secret")
      expect(user.staff?).to be true
    end

    it "returns false when password_digest is blank" do
      user = build(:user, password_digest: nil)
      expect(user.staff?).to be false
    end
  end
end
```

- [ ] **Step 4: Create the factory**

Create `spec/factories/users.rb`:

```ruby
FactoryBot.define do
  factory :user do
    phone           { "+351#{Faker::Number.number(digits: 9)}" }
    name            { Faker::Name.name }
    contact_channel { :sms }
    password_digest { nil }

    trait :staff do
      password { "password" }
    end

    trait :whatsapp do
      contact_channel { :whatsapp }
    end
  end
end
```

- [ ] **Step 5: Run spec to see it fail**

```bash
bundle exec rspec spec/models/user_spec.rb
```

Expected: failures because `User` model is empty.

- [ ] **Step 6: Write the model**

Create `app/models/user.rb`:

```ruby
class User < ApplicationRecord
  has_secure_password validations: false

  has_many :reservations, dependent: :destroy

  enum :contact_channel, { sms: 0, whatsapp: 1 }, default: :sms

  validates :phone, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: {
                      with: /\A\+[1-9]\d{6,14}\z/,
                      message: "must be in E.164 format (+country code)"
                    }
  validates :name, presence: true

  def staff?
    password_digest.present?
  end
end
```

- [ ] **Step 7: Run migration and specs**

```bash
bin/rails db:migrate
bundle exec rspec spec/models/user_spec.rb
```

Expected: all green.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: users table and model"
```

---

### Task 4: Products table + model

**Files:**
- Create: `db/migrate/*_create_products.rb`
- Create: `app/models/product.rb`
- Create: `spec/factories/products.rb`
- Create: `spec/models/product_spec.rb`

- [ ] **Step 1: Generate migration**

```bash
bin/rails generate migration CreateProducts \
  name:string \
  name_en:string \
  default_ready_time:time \
  default_daily_batch_size:integer \
  max_reservable_quantity_per_client:integer \
  active:boolean \
  "order:integer"
```

- [ ] **Step 2: Edit migration**

```ruby
class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string  :name,                               null: false
      t.string  :name_en
      t.time    :default_ready_time,                 null: false
      t.integer :default_daily_batch_size,           null: false
      t.integer :max_reservable_quantity_per_client
      t.boolean :active,                             null: false, default: true
      t.integer :order,                              null: false, default: 0

      t.timestamps
    end
  end
end
```

- [ ] **Step 3: Write the failing model spec**

Create `spec/models/product_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Product, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:product_schedule_days).dependent(:destroy) }
    it { is_expected.to have_many(:daily_inventories).dependent(:destroy) }
    it { is_expected.to have_many(:reservation_items).dependent(:restrict_with_error) }
    it { is_expected.to have_one_attached(:photo) }
    it { is_expected.to have_one_attached(:icon) }
  end

  describe "validations" do
    subject { build(:product) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:default_ready_time) }
    it { is_expected.to validate_numericality_of(:default_daily_batch_size).is_greater_than(0) }
    it {
      is_expected.to validate_numericality_of(:max_reservable_quantity_per_client)
        .is_greater_than(0)
        .allow_nil
    }
  end

  describe "#display_name" do
    let(:product) { build(:product, name: "Baguete", name_en: "Baguette") }

    it "returns Portuguese name when locale is :pt" do
      I18n.with_locale(:pt) { expect(product.display_name).to eq("Baguete") }
    end

    it "returns English name when locale is :en and name_en is present" do
      I18n.with_locale(:en) { expect(product.display_name).to eq("Baguette") }
    end

    it "falls back to Portuguese name when locale is :en but name_en is blank" do
      product.name_en = nil
      I18n.with_locale(:en) { expect(product.display_name).to eq("Baguete") }
    end
  end

  describe "scopes" do
    it ".active returns only active products" do
      active   = create(:product, active: true)
      inactive = create(:product, active: false)
      expect(Product.active).to include(active)
      expect(Product.active).not_to include(inactive)
    end

    it ".ordered sorts by order then name" do
      b = create(:product, name: "B", order: 2)
      a = create(:product, name: "A", order: 1)
      expect(Product.ordered.to_a).to eq([a, b])
    end
  end
end
```

- [ ] **Step 4: Create the factory**

Create `spec/factories/products.rb`:

```ruby
FactoryBot.define do
  factory :product do
    name                             { Faker::Food.dish }
    name_en                          { nil }
    default_ready_time               { "09:00" }
    default_daily_batch_size         { 12 }
    max_reservable_quantity_per_client { nil }
    active                           { true }
    order                            { 0 }
  end
end
```

- [ ] **Step 5: Run spec to see it fail**

```bash
bundle exec rspec spec/models/product_spec.rb
```

Expected: failures.

- [ ] **Step 6: Write the model**

Create `app/models/product.rb`:

```ruby
class Product < ApplicationRecord
  has_many :product_schedule_days, dependent: :destroy
  has_many :daily_inventories,     dependent: :destroy
  has_many :reservation_items,     dependent: :restrict_with_error

  has_one_attached :photo
  has_one_attached :icon

  scope :active,  -> { where(active: true) }
  scope :ordered, -> { order(:order, :name) }

  validates :name,                     presence: true
  validates :default_ready_time,       presence: true
  validates :default_daily_batch_size, numericality: { greater_than: 0 }
  validates :max_reservable_quantity_per_client,
            numericality: { greater_than: 0, allow_nil: true }

  def display_name
    (I18n.locale == :en && name_en.present?) ? name_en : name
  end
end
```

- [ ] **Step 7: Run migration and specs**

```bash
bin/rails db:migrate
bundle exec rspec spec/models/product_spec.rb
```

Expected: all green.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: products table and model"
```

---

### Task 5: ProductScheduleDay table + model

**Files:**
- Create: `db/migrate/*_create_product_schedule_days.rb`
- Create: `app/models/product_schedule_day.rb`
- Create: `spec/factories/product_schedule_days.rb`
- Create: `spec/models/product_schedule_day_spec.rb`

- [ ] **Step 1: Generate migration**

```bash
bin/rails generate migration CreateProductScheduleDays \
  product:references \
  day_of_week:integer
```

- [ ] **Step 2: Edit migration**

```ruby
class CreateProductScheduleDays < ActiveRecord::Migration[8.0]
  def change
    create_table :product_schedule_days do |t|
      t.references :product, null: false, foreign_key: true
      t.integer    :day_of_week, null: false

      t.timestamps
    end

    add_index :product_schedule_days, [:product_id, :day_of_week], unique: true
  end
end
```

- [ ] **Step 3: Write the failing model spec**

Create `spec/models/product_schedule_day_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe ProductScheduleDay, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:product) }
  end

  describe "validations" do
    subject { build(:product_schedule_day) }

    it { is_expected.to validate_presence_of(:day_of_week) }
    it {
      is_expected.to validate_uniqueness_of(:day_of_week)
        .scoped_to(:product_id)
    }
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:day_of_week).with_values(
        sunday: 0, monday: 1, tuesday: 2, wednesday: 3,
        thursday: 4, friday: 5, saturday: 6
      )
    }
  end
end
```

- [ ] **Step 4: Create the factory**

Create `spec/factories/product_schedule_days.rb`:

```ruby
FactoryBot.define do
  factory :product_schedule_day do
    product
    day_of_week { :tuesday }
  end
end
```

- [ ] **Step 5: Run spec to see it fail**

```bash
bundle exec rspec spec/models/product_schedule_day_spec.rb
```

- [ ] **Step 6: Write the model**

Create `app/models/product_schedule_day.rb`:

```ruby
class ProductScheduleDay < ApplicationRecord
  belongs_to :product

  enum :day_of_week, {
    sunday: 0, monday: 1, tuesday: 2, wednesday: 3,
    thursday: 4, friday: 5, saturday: 6
  }

  validates :day_of_week, presence: true,
                          uniqueness: { scope: :product_id }
end
```

- [ ] **Step 7: Run migration and specs**

```bash
bin/rails db:migrate
bundle exec rspec spec/models/product_schedule_day_spec.rb
```

Expected: all green.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: product_schedule_days table and model"
```

---

### Task 6: StoreHour table + model

**Files:**
- Create: `db/migrate/*_create_store_hours.rb`
- Create: `app/models/store_hour.rb`
- Create: `spec/factories/store_hours.rb`
- Create: `spec/models/store_hour_spec.rb`

- [ ] **Step 1: Generate migration**

```bash
bin/rails generate migration CreateStoreHours \
  day_of_week:integer \
  open:boolean \
  opens_at:time \
  closes_at:time
```

- [ ] **Step 2: Edit migration**

```ruby
class CreateStoreHours < ActiveRecord::Migration[8.0]
  def change
    create_table :store_hours do |t|
      t.integer :day_of_week, null: false
      t.boolean :open,        null: false, default: true
      t.time    :opens_at
      t.time    :closes_at

      t.timestamps
    end

    add_index :store_hours, :day_of_week, unique: true
  end
end
```

- [ ] **Step 3: Write the failing model spec**

Create `spec/models/store_hour_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe StoreHour, type: :model do
  describe "validations" do
    subject { build(:store_hour) }

    it { is_expected.to validate_presence_of(:day_of_week) }
    it { is_expected.to validate_uniqueness_of(:day_of_week) }

    it "requires opens_at and closes_at when open" do
      sh = build(:store_hour, open: true, opens_at: nil, closes_at: nil)
      expect(sh).not_to be_valid
      expect(sh.errors[:opens_at]).to be_present
      expect(sh.errors[:closes_at]).to be_present
    end

    it "does not require times when closed" do
      sh = build(:store_hour, open: false, opens_at: nil, closes_at: nil)
      expect(sh).to be_valid
    end
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:day_of_week).with_values(
        sunday: 0, monday: 1, tuesday: 2, wednesday: 3,
        thursday: 4, friday: 5, saturday: 6
      )
    }
  end

  describe ".for_date" do
    it "returns the store hour record for a given date's weekday" do
      tuesday = create(:store_hour, day_of_week: :tuesday)
      date    = Date.new(2026, 6, 23) # a Tuesday
      expect(StoreHour.for_date(date)).to eq(tuesday)
    end
  end
end
```

- [ ] **Step 4: Create the factory**

Create `spec/factories/store_hours.rb`:

```ruby
FactoryBot.define do
  factory :store_hour do
    day_of_week { :tuesday }
    open        { true }
    opens_at    { "08:00" }
    closes_at   { "18:00" }

    trait :closed do
      open      { false }
      opens_at  { nil }
      closes_at { nil }
    end
  end
end
```

- [ ] **Step 5: Run spec to see it fail**

```bash
bundle exec rspec spec/models/store_hour_spec.rb
```

- [ ] **Step 6: Write the model**

Create `app/models/store_hour.rb`:

```ruby
class StoreHour < ApplicationRecord
  enum :day_of_week, {
    sunday: 0, monday: 1, tuesday: 2, wednesday: 3,
    thursday: 4, friday: 5, saturday: 6
  }

  validates :day_of_week, presence: true, uniqueness: true
  validates :opens_at, :closes_at, presence: true, if: :open?

  def self.for_date(date)
    find_by(day_of_week: date.wday)
  end
end
```

- [ ] **Step 7: Run migration and specs**

```bash
bin/rails db:migrate
bundle exec rspec spec/models/store_hour_spec.rb
```

Expected: all green.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: store_hours table and model"
```

---

### Task 7: StoreException table + model

**Files:**
- Create: `db/migrate/*_create_store_exceptions.rb`
- Create: `app/models/store_exception.rb`
- Create: `spec/factories/store_exceptions.rb`
- Create: `spec/models/store_exception_spec.rb`

- [ ] **Step 1: Generate migration**

```bash
bin/rails generate migration CreateStoreExceptions \
  date:date \
  closed:boolean \
  opens_at:time \
  closes_at:time \
  reason:string
```

- [ ] **Step 2: Edit migration**

```ruby
class CreateStoreExceptions < ActiveRecord::Migration[8.0]
  def change
    create_table :store_exceptions do |t|
      t.date    :date,      null: false
      t.boolean :closed,    null: false, default: true
      t.time    :opens_at
      t.time    :closes_at
      t.string  :reason,    null: false

      t.timestamps
    end

    add_index :store_exceptions, :date, unique: true
  end
end
```

- [ ] **Step 3: Write the failing model spec**

Create `spec/models/store_exception_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe StoreException, type: :model do
  describe "validations" do
    subject { build(:store_exception) }

    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_uniqueness_of(:date) }
    it { is_expected.to validate_presence_of(:reason) }

    it "requires opens_at and closes_at when not closed" do
      exc = build(:store_exception, closed: false, opens_at: nil, closes_at: nil)
      expect(exc).not_to be_valid
      expect(exc.errors[:opens_at]).to be_present
      expect(exc.errors[:closes_at]).to be_present
    end

    it "does not require times when closed" do
      exc = build(:store_exception, closed: true, opens_at: nil, closes_at: nil)
      expect(exc).to be_valid
    end
  end

  describe ".for_date" do
    it "returns the exception for a given date" do
      exception = create(:store_exception, date: Date.new(2026, 12, 25))
      expect(StoreException.for_date(Date.new(2026, 12, 25))).to eq(exception)
    end

    it "returns nil when no exception exists" do
      expect(StoreException.for_date(Date.new(2026, 12, 26))).to be_nil
    end
  end
end
```

- [ ] **Step 4: Create the factory**

Create `spec/factories/store_exceptions.rb`:

```ruby
FactoryBot.define do
  factory :store_exception do
    date   { Faker::Date.forward(days: 30) }
    closed { true }
    reason { "Public holiday" }

    trait :different_hours do
      closed    { false }
      opens_at  { "10:00" }
      closes_at { "14:00" }
    end
  end
end
```

- [ ] **Step 5: Run spec to see it fail**

```bash
bundle exec rspec spec/models/store_exception_spec.rb
```

- [ ] **Step 6: Write the model**

Create `app/models/store_exception.rb`:

```ruby
class StoreException < ApplicationRecord
  validates :date,   presence: true, uniqueness: true
  validates :reason, presence: true
  validates :opens_at, :closes_at, presence: true, if: -> { !closed? }

  def self.for_date(date)
    find_by(date: date)
  end
end
```

- [ ] **Step 7: Run migration and specs**

```bash
bin/rails db:migrate
bundle exec rspec spec/models/store_exception_spec.rb
```

Expected: all green.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: store_exceptions table and model"
```

---

### Task 8: DailyInventory table + model

**Files:**
- Create: `db/migrate/*_create_daily_inventories.rb`
- Create: `app/models/daily_inventory.rb`
- Create: `spec/factories/daily_inventories.rb`
- Create: `spec/models/daily_inventory_spec.rb`

- [ ] **Step 1: Generate migration**

```bash
bin/rails generate migration CreateDailyInventories \
  product:references \
  date:date \
  batch_size:integer \
  ready_time_override:time \
  skipped:boolean \
  added:boolean
```

- [ ] **Step 2: Edit migration**

```ruby
class CreateDailyInventories < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_inventories do |t|
      t.references :product,            null: false, foreign_key: true
      t.date       :date,               null: false
      t.integer    :batch_size,         null: false
      t.time       :ready_time_override
      t.boolean    :skipped,            null: false, default: false
      t.boolean    :added,              null: false, default: false

      t.timestamps
    end

    add_index :daily_inventories, [:product_id, :date], unique: true
  end
end
```

- [ ] **Step 3: Write the failing model spec**

Create `spec/models/daily_inventory_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe DailyInventory, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:product) }
  end

  describe "validations" do
    subject { build(:daily_inventory) }

    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_uniqueness_of(:date).scoped_to(:product_id) }
    it { is_expected.to validate_numericality_of(:batch_size).is_greater_than_or_equal_to(0) }
  end

  describe "#effective_ready_time" do
    let(:product) { build(:product, default_ready_time: "09:00") }

    it "returns the override when set" do
      inv = build(:daily_inventory, product: product, ready_time_override: "11:30")
      expect(inv.effective_ready_time.strftime("%H:%M")).to eq("11:30")
    end

    it "falls back to the product default when no override" do
      inv = build(:daily_inventory, product: product, ready_time_override: nil)
      expect(inv.effective_ready_time.strftime("%H:%M")).to eq("09:00")
    end
  end

  describe ".for_product_on" do
    it "returns existing record" do
      product = create(:product)
      inv     = create(:daily_inventory, product: product, date: Date.today)
      expect(DailyInventory.for_product_on(product, Date.today)).to eq(inv)
    end

    it "initializes a new record with default batch size when none exists" do
      product = create(:product, default_daily_batch_size: 10)
      inv = DailyInventory.for_product_on(product, Date.tomorrow)
      expect(inv).to be_new_record
      expect(inv.batch_size).to eq(10)
    end
  end
end
```

- [ ] **Step 4: Create the factory**

Create `spec/factories/daily_inventories.rb`:

```ruby
FactoryBot.define do
  factory :daily_inventory do
    product
    date               { Date.today }
    batch_size         { 12 }
    ready_time_override { nil }
    skipped            { false }
    added              { false }
  end
end
```

- [ ] **Step 5: Run spec to see it fail**

```bash
bundle exec rspec spec/models/daily_inventory_spec.rb
```

- [ ] **Step 6: Write the model**

Create `app/models/daily_inventory.rb`:

```ruby
class DailyInventory < ApplicationRecord
  belongs_to :product

  validates :date,       presence: true, uniqueness: { scope: :product_id }
  validates :batch_size, numericality: { greater_than_or_equal_to: 0 }

  def effective_ready_time
    ready_time_override || product.default_ready_time
  end

  def self.for_product_on(product, date)
    find_or_initialize_by(product: product, date: date) do |inv|
      inv.batch_size = product.default_daily_batch_size
    end
  end
end
```

- [ ] **Step 7: Run migration and specs**

```bash
bin/rails db:migrate
bundle exec rspec spec/models/daily_inventory_spec.rb
```

Expected: all green.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: daily_inventories table and model"
```

---

### Task 9: Reservations + ReservationItems tables + models

**Files:**
- Create: `db/migrate/*_create_reservations.rb`
- Create: `db/migrate/*_create_reservation_items.rb`
- Create: `app/models/reservation.rb`
- Create: `app/models/reservation_item.rb`
- Create: `spec/factories/reservations.rb`
- Create: `spec/factories/reservation_items.rb`
- Create: `spec/models/reservation_spec.rb`
- Create: `spec/models/reservation_item_spec.rb`

- [ ] **Step 1: Generate reservations migration**

```bash
bin/rails generate migration CreateReservations \
  user:references \
  date:date \
  pickup_time:time \
  note:text \
  source:integer \
  collected_at:datetime \
  cancelled:boolean
```

- [ ] **Step 2: Edit reservations migration**

```ruby
class CreateReservations < ActiveRecord::Migration[8.0]
  def change
    create_table :reservations do |t|
      t.references :user,        null: false, foreign_key: true
      t.date       :date,        null: false
      t.time       :pickup_time
      t.text       :note
      t.integer    :source,      null: false
      t.datetime   :collected_at
      t.boolean    :cancelled,   null: false, default: false

      t.timestamps
    end
  end
end
```

- [ ] **Step 3: Generate reservation_items migration**

```bash
bin/rails generate migration CreateReservationItems \
  reservation:references \
  product:references \
  quantity:integer
```

- [ ] **Step 4: Edit reservation_items migration**

```ruby
class CreateReservationItems < ActiveRecord::Migration[8.0]
  def change
    create_table :reservation_items do |t|
      t.references :reservation, null: false, foreign_key: true
      t.references :product,     null: false, foreign_key: true
      t.integer    :quantity,    null: false

      t.timestamps
    end

    add_index :reservation_items, [:reservation_id, :product_id], unique: true
  end
end
```

- [ ] **Step 5: Write failing Reservation spec**

Create `spec/models/reservation_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Reservation, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:reservation_items).dependent(:destroy) }
    it { is_expected.to have_many(:products).through(:reservation_items) }
  end

  describe "validations" do
    subject { build(:reservation) }

    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:source) }
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:source).with_values(
        sms: 0, whatsapp: 1, phone: 2, counter: 3, online: 4
      )
    }
  end

  describe "scopes" do
    let!(:upcoming)   { create(:reservation, cancelled: false, collected_at: nil, date: Date.tomorrow) }
    let!(:collected)  { create(:reservation, cancelled: false, collected_at: Time.current, date: Date.yesterday) }
    let!(:cancelled)  { create(:reservation, cancelled: true) }

    it ".active excludes cancelled" do
      expect(Reservation.active).to include(upcoming, collected)
      expect(Reservation.active).not_to include(cancelled)
    end

    it ".upcoming returns active, uncollected, future-or-today reservations" do
      expect(Reservation.upcoming).to include(upcoming)
      expect(Reservation.upcoming).not_to include(collected, cancelled)
    end

    it ".collected returns active and collected" do
      expect(Reservation.collected).to include(collected)
      expect(Reservation.collected).not_to include(upcoming, cancelled)
    end
  end

  describe "#collected?" do
    it "returns true when collected_at is set" do
      r = build(:reservation, collected_at: Time.current)
      expect(r.collected?).to be true
    end

    it "returns false when collected_at is nil" do
      r = build(:reservation, collected_at: nil)
      expect(r.collected?).to be false
    end
  end

  describe "#cancellable?" do
    it "returns true when not collected and not cancelled" do
      r = build(:reservation, collected_at: nil, cancelled: false)
      expect(r.cancellable?).to be true
    end

    it "returns false when already collected" do
      r = build(:reservation, collected_at: Time.current, cancelled: false)
      expect(r.cancellable?).to be false
    end

    it "returns false when already cancelled" do
      r = build(:reservation, collected_at: nil, cancelled: true)
      expect(r.cancellable?).to be false
    end
  end
end
```

- [ ] **Step 6: Write failing ReservationItem spec**

Create `spec/models/reservation_item_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe ReservationItem, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:reservation) }
    it { is_expected.to belong_to(:product) }
  end

  describe "validations" do
    subject { build(:reservation_item) }

    it { is_expected.to validate_numericality_of(:quantity).is_greater_than(0) }
    it { is_expected.to validate_uniqueness_of(:product_id).scoped_to(:reservation_id) }
  end
end
```

- [ ] **Step 7: Create factories**

Create `spec/factories/reservations.rb`:

```ruby
FactoryBot.define do
  factory :reservation do
    user
    date         { Date.tomorrow }
    pickup_time  { nil }
    note         { nil }
    source       { :online }
    collected_at { nil }
    cancelled    { false }
  end
end
```

Create `spec/factories/reservation_items.rb`:

```ruby
FactoryBot.define do
  factory :reservation_item do
    reservation
    product
    quantity { 1 }
  end
end
```

- [ ] **Step 8: Run specs to see failures**

```bash
bundle exec rspec spec/models/reservation_spec.rb spec/models/reservation_item_spec.rb
```

- [ ] **Step 9: Write Reservation model**

Create `app/models/reservation.rb`:

```ruby
class Reservation < ApplicationRecord
  belongs_to :user
  has_many :reservation_items, dependent: :destroy
  has_many :products, through: :reservation_items

  enum :source, { sms: 0, whatsapp: 1, phone: 2, counter: 3, online: 4 }

  scope :active,   -> { where(cancelled: false) }
  scope :upcoming, -> { active.where(collected_at: nil).where("date >= ?", Date.current) }
  scope :collected, -> { active.where.not(collected_at: nil) }

  validates :date,   presence: true
  validates :source, presence: true

  def collected?
    collected_at.present?
  end

  def cancellable?
    !collected? && !cancelled?
  end
end
```

- [ ] **Step 10: Write ReservationItem model**

Create `app/models/reservation_item.rb`:

```ruby
class ReservationItem < ApplicationRecord
  belongs_to :reservation
  belongs_to :product

  validates :quantity,   numericality: { greater_than: 0 }
  validates :product_id, uniqueness: { scope: :reservation_id }
end
```

- [ ] **Step 11: Run migrations and specs**

```bash
bin/rails db:migrate
bundle exec rspec spec/models/reservation_spec.rb spec/models/reservation_item_spec.rb
```

Expected: all green.

- [ ] **Step 12: Run the full suite**

```bash
bundle exec rspec
```

Expected: all green.

- [ ] **Step 13: Commit**

```bash
git add -A
git commit -m "feat: reservations and reservation_items tables and models"
```

---

### Task 10: Staff authentication

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Create: `app/controllers/sessions_controller.rb`
- Create: `app/controllers/staff/base_controller.rb`
- Create: `app/views/sessions/new.html.erb`
- Modify: `config/routes.rb`
- Create: `spec/requests/sessions_spec.rb`

- [ ] **Step 1: Write the failing request spec**

Create `spec/requests/sessions_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let!(:staff) { create(:user, :staff, phone: "+351912000001", name: "Staff") }

  describe "POST /login" do
    it "logs in a staff user with correct credentials" do
      post login_path, params: { phone: staff.phone, password: "password" }
      expect(response).to redirect_to(staff_root_path)
      follow_redirect!
      expect(response).to be_successful
    end

    it "rejects wrong password" do
      post login_path, params: { phone: staff.phone, password: "wrong" }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects a non-staff user (no password_digest)" do
      customer = create(:user, phone: "+351912000002")
      post login_path, params: { phone: customer.phone, password: "anything" }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /logout" do
    it "clears the session and redirects to root" do
      post login_path, params: { phone: staff.phone, password: "password" }
      delete logout_path
      expect(response).to redirect_to(root_path)
    end
  end
end
```

- [ ] **Step 2: Run spec to see it fail**

```bash
bundle exec rspec spec/requests/sessions_spec.rb
```

Expected: failures (routes and controllers don't exist yet).

- [ ] **Step 3: Write ApplicationController**

Replace `app/controllers/application_controller.rb`:

```ruby
class ApplicationController < ActionController::Base
  helper_method :current_staff_user, :staff_logged_in?

  before_action :set_locale

  private

  def current_staff_user
    @current_staff_user ||= User.find_by(id: session[:staff_user_id])
  end

  def staff_logged_in?
    current_staff_user.present?
  end

  def require_staff!
    unless staff_logged_in?
      redirect_to login_path, alert: t("auth.login_required")
    end
  end

  def set_locale
    locale = session[:locale]&.to_sym
    I18n.locale = I18n.available_locales.include?(locale) ? locale : I18n.default_locale
  end
end
```

- [ ] **Step 4: Write SessionsController**

Create `app/controllers/sessions_controller.rb`:

```ruby
class SessionsController < ApplicationController
  def new
    redirect_to staff_root_path if staff_logged_in?
  end

  def create
    user = User.find_by(phone: params[:phone])
    if user&.staff? && user.authenticate(params[:password])
      session[:staff_user_id] = user.id
      redirect_to staff_root_path
    else
      flash.now[:alert] = t("auth.invalid_credentials")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:staff_user_id)
    redirect_to root_path
  end
end
```

- [ ] **Step 5: Write Staff::BaseController**

Create `app/controllers/staff/base_controller.rb`:

```ruby
module Staff
  class BaseController < ApplicationController
    layout "staff"
    before_action :require_staff!
  end
end
```

- [ ] **Step 6: Write Staff::DashboardController**

Create `app/controllers/staff/dashboard_controller.rb`:

```ruby
module Staff
  class DashboardController < Staff::BaseController
    def index
    end
  end
end
```

- [ ] **Step 7: Configure routes**

Replace `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  root "pages#home"

  get    "/login",  to: "sessions#new",     as: :login
  post   "/login",  to: "sessions#create"
  delete "/logout", to: "sessions#destroy", as: :logout

  patch "/locale", to: "locales#update", as: :locale

  namespace :staff do
    root "dashboard#index"
  end
end
```

- [ ] **Step 8: Create minimal PagesController placeholder**

Create `app/controllers/pages_controller.rb`:

```ruby
class PagesController < ApplicationController
  def home
    render plain: "Massa Mater"
  end
end
```

- [ ] **Step 9: Create login view**

Create `app/views/sessions/new.html.erb`:

```erb
<h1><%= t("auth.sign_in") %></h1>

<%= form_tag login_path do %>
  <% if flash[:alert] %>
    <p><%= flash[:alert] %></p>
  <% end %>

  <div>
    <label><%= t("auth.phone") %></label>
    <%= telephone_field_tag :phone, nil, autocomplete: "tel" %>
  </div>

  <div>
    <label><%= t("auth.password") %></label>
    <%= password_field_tag :password, nil, autocomplete: "current-password" %>
  </div>

  <%= submit_tag t("auth.sign_in_button") %>
<% end %>
```

- [ ] **Step 10: Create staff dashboard placeholder**

Create `app/views/staff/dashboard/index.html.erb`:

```erb
<h1>Staff dashboard</h1>
<p><%= t("staff.dashboard.placeholder") %></p>
```

- [ ] **Step 11: Run sessions spec**

```bash
bundle exec rspec spec/requests/sessions_spec.rb
```

Expected: all green. (The staff layout doesn't exist yet — Task 11 adds it. If the test fails on missing layout, temporarily stub it with `layout false` in `Staff::BaseController`, run the spec, then revert.)

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "feat: staff authentication (sessions controller + route guards)"
```

---

### Task 11: i18n setup

**Files:**
- Modify: `config/application.rb`
- Create: `config/locales/pt.yml`
- Create: `config/locales/en.yml`
- Create: `app/controllers/locales_controller.rb`

- [ ] **Step 1: Configure default locale in application.rb**

Add inside the `class Application < Rails::Application` block in `config/application.rb`:

```ruby
config.i18n.default_locale  = :pt
config.i18n.available_locales = [:pt, :en]
config.i18n.fallbacks = true
```

- [ ] **Step 2: Create Portuguese locale file**

Create `config/locales/pt.yml`:

```yaml
pt:
  auth:
    sign_in: "Entrar"
    sign_in_button: "Entrar"
    phone: "Número de telemóvel"
    password: "Palavra-passe"
    login_required: "Por favor inicia sessão para continuar."
    invalid_credentials: "Número ou palavra-passe incorretos."
  staff:
    nav:
      today: "Hoje"
      inventory: "Inventário"
      products: "Produtos"
      settings: "Definições"
    dashboard:
      placeholder: "Painel de controlo"
  customer:
    new_reservation: "Nova reserva"
    manage_orders: "As minhas encomendas"
    continue: "Continuar"
    find_orders: "Continuar"
    phone_number: "Número de telemóvel"
    name: "Nome"
    note: "Nota (opcional)"
    pickup_date: "Data de levantamento"
    pickup_time: "Hora de levantamento"
    confirm_reservation: "Confirmar reserva"
    cancel: "Cancelar"
    edit: "Editar"
    repeat_order: "Repetir esta encomenda"
    upcoming: "Próxima"
    collected: "Levantada"
  products:
    available_from: "Disponível a partir das %{time}"
    sold_out: "Esgotado"
    fully_reserved: "Totalmente reservado"
    remaining: "%{count} restante(s)"
  store:
    closed: "Fechado"
  date:
    formats:
      short_with_day: "%A, %d %b"
```

- [ ] **Step 3: Create English locale file**

Create `config/locales/en.yml`:

```yaml
en:
  auth:
    sign_in: "Sign in"
    sign_in_button: "Sign in"
    phone: "Phone number"
    password: "Password"
    login_required: "Please sign in to continue."
    invalid_credentials: "Phone number or password is incorrect."
  staff:
    nav:
      today: "Today"
      inventory: "Inventory"
      products: "Products"
      settings: "Settings"
    dashboard:
      placeholder: "Dashboard"
  customer:
    new_reservation: "New reservation"
    manage_orders: "My orders"
    continue: "Continue"
    find_orders: "Continue"
    phone_number: "Phone number"
    name: "Name"
    note: "Note (optional)"
    pickup_date: "Pickup date"
    pickup_time: "Pickup time"
    confirm_reservation: "Confirm reservation"
    cancel: "Cancel"
    edit: "Edit"
    repeat_order: "Repeat this order"
    upcoming: "Upcoming"
    collected: "Collected"
  products:
    available_from: "Available from %{time}"
    sold_out: "Sold out"
    fully_reserved: "Fully reserved"
    remaining: "%{count} remaining"
  store:
    closed: "Closed"
  date:
    formats:
      short_with_day: "%A, %b %-d"
```

- [ ] **Step 4: Write LocalesController**

Create `app/controllers/locales_controller.rb`:

```ruby
class LocalesController < ApplicationController
  def update
    locale = params[:locale]&.to_sym
    if I18n.available_locales.include?(locale)
      session[:locale] = locale
    end
    redirect_back fallback_location: root_path
  end
end
```

- [ ] **Step 5: Verify i18n works**

```bash
bin/rails runner "I18n.locale = :en; puts I18n.t('auth.sign_in')"
```

Expected: `Sign in`

```bash
bin/rails runner "I18n.locale = :pt; puts I18n.t('auth.sign_in')"
```

Expected: `Entrar`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: i18n setup with PT and EN locales"
```

---

### Task 12: Application layouts

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Create: `app/views/layouts/staff.html.erb`

- [ ] **Step 1: Update the base application layout**

Replace `app/views/layouts/application.html.erb`:

```erb
<!DOCTYPE html>
<html lang="<%= I18n.locale %>">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Massa Mater</title>
  <%= csrf_meta_tags %>
  <%= csp_meta_tag %>
  <%= stylesheet_link_tag "application" %>
</head>
<body>
  <%= yield %>
</body>
</html>
```

- [ ] **Step 2: Create the staff layout**

Create `app/views/layouts/staff.html.erb`:

```erb
<!DOCTYPE html>
<html lang="<%= I18n.locale %>">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Massa Mater — Staff</title>
  <%= csrf_meta_tags %>
  <%= csp_meta_tag %>
  <%= stylesheet_link_tag "application" %>
</head>
<body>
  <nav>
    <%= link_to t("staff.nav.today"),      staff_root_path %>
    <%= link_to t("staff.nav.inventory"),  "#" %>
    <%= link_to t("staff.nav.products"),   "#" %>
    <%= link_to t("staff.nav.settings"),   "#" %>

    <span>
      <%= button_to "PT", locale_path(locale: :pt), method: :patch %>
      <%= button_to "EN", locale_path(locale: :en), method: :patch %>
    </span>

    <%= button_to t("auth.sign_in"), logout_path, method: :delete %>
  </nav>

  <main>
    <%= flash[:alert].present? ? content_tag(:p, flash[:alert]) : "" %>
    <%= yield %>
  </main>
</body>
</html>
```

- [ ] **Step 3: Verify the staff dashboard renders**

```bash
bin/rails server
```

Visit `http://localhost:3000/login`. Sign in with the seed credentials (set up in Task 13). Expected: nav with Today / Inventory / Products / Settings. Stop the server.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: application and staff layouts"
```

---

### Task 13: Fly.io deployment configuration

**Files:**
- Modify: `config/database.yml`
- Modify: `fly.toml` (generated by `fly launch`)

- [ ] **Step 1: Run fly launch to generate fly.toml**

```bash
fly launch --no-deploy
```

When prompted:
- App name: `massa-mater` (or your preferred name)
- Region: closest to Portugal — `mad` (Madrid) is typically best for EU
- Choose not to set up Postgresql or Redis

This generates `fly.toml` and `Dockerfile`.

- [ ] **Step 2: Create the persistent volume**

```bash
fly volumes create sqlite_data --size 1 --region mad
```

- [ ] **Step 3: Configure the volume mount in fly.toml**

Add to `fly.toml` (if not already present):

```toml
[mounts]
  source      = "sqlite_data"
  destination = "/data"
```

- [ ] **Step 4: Update database.yml for production**

In `config/database.yml`, update the production section:

```yaml
production:
  adapter: sqlite3
  database: /data/db/production.sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000
```

- [ ] **Step 5: Add pre-deploy database setup command in fly.toml**

This ensures migrations run automatically on each deploy:

```toml
[deploy]
  release_command = "bin/rails db:prepare"
```

- [ ] **Step 6: Set RAILS_MASTER_KEY secret**

```bash
fly secrets set RAILS_MASTER_KEY=$(cat config/master.key)
```

- [ ] **Step 7: Deploy**

```bash
fly deploy
```

Expected: build succeeds, release command runs `db:prepare`, app starts.

- [ ] **Step 8: Verify the deployed app**

```bash
fly open /login
```

Expected: login page loads.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "chore: Fly.io deployment config with SQLite persistent volume"
```

---

### Task 14: Seed data

**Files:**
- Modify: `db/seeds.rb`

- [ ] **Step 1: Write seeds**

Replace `db/seeds.rb`:

```ruby
# Staff user — phone: +351912000001, password: password
User.find_or_create_by!(phone: "+351912000001") do |u|
  u.name            = "Staff"
  u.contact_channel = :sms
  u.password        = "password"
end

# Weekly store hours
# 0=Sunday 1=Monday 2=Tuesday 3=Wednesday 4=Thursday 5=Friday 6=Saturday
[
  { day_of_week: :sunday,    open: false },
  { day_of_week: :monday,    open: false },
  { day_of_week: :tuesday,   open: true, opens_at: "08:00", closes_at: "18:00" },
  { day_of_week: :wednesday, open: true, opens_at: "08:00", closes_at: "18:00" },
  { day_of_week: :thursday,  open: true, opens_at: "08:00", closes_at: "18:00" },
  { day_of_week: :friday,    open: true, opens_at: "08:00", closes_at: "18:00" },
  { day_of_week: :saturday,  open: true, opens_at: "09:00", closes_at: "15:00" },
].each do |attrs|
  StoreHour.find_or_create_by!(day_of_week: attrs[:day_of_week]) do |sh|
    sh.open      = attrs[:open]
    sh.opens_at  = attrs[:opens_at]
    sh.closes_at = attrs[:closes_at]
  end
end

# Sample products
[
  {
    name: "Baguete", name_en: "Baguette",
    default_ready_time: "08:00", default_daily_batch_size: 20,
    max_reservable_quantity_per_client: 4, active: true, order: 1,
    days: %i[tuesday wednesday thursday friday saturday]
  },
  {
    name: "Broa de Milho", name_en: "Corn Bread",
    default_ready_time: "09:00", default_daily_batch_size: 12,
    max_reservable_quantity_per_client: 2, active: true, order: 2,
    days: %i[tuesday wednesday thursday friday saturday]
  },
  {
    name: "Cinnamon Rolls", name_en: "Cinnamon Rolls",
    default_ready_time: "10:00", default_daily_batch_size: 10,
    max_reservable_quantity_per_client: 4, active: true, order: 3,
    days: %i[friday saturday]
  },
  {
    name: "Granola", name_en: "Granola",
    default_ready_time: "08:00", default_daily_batch_size: 15,
    max_reservable_quantity_per_client: nil, active: true, order: 4,
    days: %i[thursday friday saturday]
  },
  {
    name: "Bolachas", name_en: "Cookies",
    default_ready_time: "09:00", default_daily_batch_size: 24,
    max_reservable_quantity_per_client: 6, active: false, order: 5,
    days: %i[tuesday wednesday thursday friday]
  },
].each do |attrs|
  days = attrs.delete(:days)
  product = Product.find_or_create_by!(name: attrs[:name]) do |p|
    p.assign_attributes(attrs)
  end
  days.each { |day| product.product_schedule_days.find_or_create_by!(day_of_week: day) }
end

puts "Seeded: 1 staff user, 7 store hours, #{Product.count} products"
```

- [ ] **Step 2: Run seeds locally**

```bash
bin/rails db:seed
```

Expected: `Seeded: 1 staff user, 7 store hours, 5 products`

- [ ] **Step 3: Run full spec suite to confirm nothing broken**

```bash
bundle exec rspec
```

Expected: all green.

- [ ] **Step 4: Run seeds on the deployed app**

```bash
fly ssh console -C "bin/rails db:seed"
```

- [ ] **Step 5: Commit**

```bash
git add db/seeds.rb
git commit -m "chore: seed staff user, store hours, sample products"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Covered in |
|---|---|
| users table + phone uniqueness + E.164 | Task 3 |
| password_digest nullable, has_secure_password | Task 3 |
| staff? helper | Task 3 |
| products table + Active Storage icon + photo | Task 4 |
| display_name PT/EN fallback | Task 4 |
| product_schedule_days (day_of_week 0–6) | Task 5 |
| store_hours (7 rows, open toggle, times) | Task 6 |
| store_exceptions (one-off date overrides) | Task 7 |
| daily_inventory + effective_ready_time | Task 8 |
| reservations (source enum, cancelled, collected_at) | Task 9 |
| reservation_items | Task 9 |
| Reservation#cancellable? | Task 9 |
| Staff auth via session | Task 10 |
| require_staff! guard | Task 10 |
| i18n PT default, EN toggle via session | Task 11 |
| Staff layout + nav (Today/Inventory/Products/Settings) | Task 12 |
| Fly.io + SQLite persistent volume | Task 13 |
| Seed data | Task 14 |

All spec requirements are covered. Feature plans (4.1–4.8) build controllers, views, and Turbo interactions on top of this foundation.
