module Staff
  class DashboardController < Staff::BaseController
    def index
      @day = DayPresenter.new(Date.current)
    end
  end
end
