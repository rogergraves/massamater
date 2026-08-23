module Staff
  class DashboardController < Staff::BaseController
    def index
      today = Date.current
      @day = DayPresenter.new(today)
      unless DayPresenter.open_on?(today)
        next_date = DayPresenter.next_open_date(from: today)
        @next_day = DayPresenter.new(next_date) if next_date
        week_start = today - today.wday
        week_end   = week_start + 6
        res_counts = Reservation.active
                                .where(date: week_start..week_end)
                                .group(:date)
                                .count
        @week = (0..6).map do |i|
          date = week_start + i
          { date: date, hour: StoreHour.for_date(date), exception: StoreException.for_date(date), reservations: res_counts[date] || 0 }
        end
      end
    end
  end
end
