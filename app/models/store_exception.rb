class StoreException < ApplicationRecord
  validates :date,   presence: true, uniqueness: true
  validates :reason, presence: true
  validates :opens_at, :closes_at, presence: true, if: -> { !closed? }

  def self.for_date(date)
    find_by(date: date)
  end
end
