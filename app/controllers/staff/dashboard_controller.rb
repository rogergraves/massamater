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
