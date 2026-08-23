class StoreException < ApplicationRecord
  validates :start_date, presence: true
  validates :reason,     presence: true
  validates :opens_at, :closes_at, presence: true, if: -> { !closed? }
  validate  :end_date_not_before_start_date

  def self.for_date(date)
    where(
      "(end_date IS NULL AND start_date = ?) OR (end_date IS NOT NULL AND start_date <= ? AND end_date >= ?)",
      date, date, date
    ).first
  end

  def single_day?
    end_date.nil? || end_date == start_date
  end

  def display_date
    if single_day?
      start_date.strftime("%b %-d, %Y")
    else
      "#{start_date.strftime("%b %-d")} – #{end_date.strftime("%b %-d, %Y")}"
    end
  end

  private

  def end_date_not_before_start_date
    return unless start_date && end_date
    errors.add(:end_date, :invalid) if end_date < start_date
  end
end
