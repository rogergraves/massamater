class Staff::StoreExceptionsController < Staff::BaseController
  def create
    @exception = StoreException.new(exception_params)
    if @exception.save
      redirect_to edit_staff_store_hours_path, notice: t("store_hours.exceptions.added")
    else
      @store_hours   = StoreHour.order(:day_of_week)
      @exceptions    = StoreException.where("start_date >= ?", Date.current).order(:start_date)
      @new_exception = @exception
      render "staff/store_hours/edit", status: :unprocessable_entity
    end
  end

  def destroy
    StoreException.find(params[:id]).destroy
    redirect_to edit_staff_store_hours_path, notice: t("store_hours.exceptions.removed")
  end

  private

  def exception_params
    params.require(:store_exception).permit(:start_date, :end_date, :reason, :closed, :opens_at, :closes_at)
  end
end
