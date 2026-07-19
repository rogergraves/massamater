class DayPresenter
  attr_reader :date

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

  def self.open_on?(date)
    exc = StoreException.for_date(date)
    return false if exc&.closed?
    hour = StoreHour.for_date(date)
    hour&.open? || false
  end

  def self.next_open_date(from:)
    candidates = (1..14).map { |i| from + i }
    exceptions = StoreException.where(date: candidates, closed: true).pluck(:date).to_set
    open_wdays = StoreHour.where(open: true)
                         .pluck(:day_of_week)
                         .map { |d| d.is_a?(Integer) ? d : StoreHour.day_of_weeks[d] }
                         .to_set

    candidates.each do |date|
      next if exceptions.include?(date)
      return date if open_wdays.include?(date.wday)
    end
    nil
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
