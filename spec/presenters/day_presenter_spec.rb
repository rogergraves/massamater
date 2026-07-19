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
      expect(DayPresenter.next_open_date(from: Date.new(2026, 7, 20))).to be_nil
    end

    it "returns the next date that is open" do
      wednesday = Date.new(2026, 7, 22) # wday=3
      StoreHour.create!(day_of_week: :wednesday, open: true, opens_at: "09:00", closes_at: "17:00")
      result = DayPresenter.next_open_date(from: Date.new(2026, 7, 20))
      expect(result).to eq(wednesday)
    end

    it "skips dates with a closed StoreException even if the weekday is open" do
      StoreHour.create!(day_of_week: :wednesday, open: true, opens_at: "09:00", closes_at: "17:00")
      first_wednesday = Date.new(2026, 7, 22)
      StoreException.create!(date: first_wednesday, reason: "Holiday", closed: true)
      second_wednesday = Date.new(2026, 7, 29)
      result = DayPresenter.next_open_date(from: Date.new(2026, 7, 20))
      expect(result).to eq(second_wednesday)
    end
  end
end
