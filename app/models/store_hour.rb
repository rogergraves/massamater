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
