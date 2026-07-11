class Staff::StoreHoursController < Staff::BaseController
  def edit
    @store_hours   = StoreHour.order(:day_of_week)
    @exceptions    = StoreException.where("date >= ?", Date.current).order(:date)
    @new_exception = StoreException.new
  end

  def update
    hours_params = params[:store_hours] || {}
    StoreHour.order(:day_of_week).each do |hour|
      attrs = hours_params[hour.id.to_s] || {}
      hour.update!(
        open:      attrs[:open] == "1",
        opens_at:  attrs[:opens_at].presence || hour.opens_at,
        closes_at: attrs[:closes_at].presence || hour.closes_at
      )
    end
    redirect_to edit_staff_store_hours_path, notice: t("store_hours.saved")
  end
end
