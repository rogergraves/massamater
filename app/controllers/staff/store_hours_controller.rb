class Staff::StoreHoursController < Staff::BaseController
  def edit
    @store_hours   = StoreHour.order(:day_of_week)
    @exceptions    = StoreException.where("date >= ?", Date.current).order(:date)
    @new_exception = StoreException.new
  end

  def update
    (params[:store_hours] || {}).each do |id, attrs|
      hour = StoreHour.find(id)
      open = attrs[:open] == "1"
      hour.update!(open: open,
                   opens_at:  attrs[:opens_at],
                   closes_at: attrs[:closes_at])
    end
    redirect_to edit_staff_store_hours_path, notice: t("store_hours.saved")
  end
end
