module Staff
  class DashboardController < Staff::BaseController
    def index
      today = Date.current
      @selected_date = params[:date].present? ? Date.parse(params[:date]) : today

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

      @day        = DayPresenter.new(@selected_date)
      @day_open   = DayPresenter.open_on?(@selected_date)
    rescue ArgumentError
      redirect_to staff_root_path
    end
  end
end
