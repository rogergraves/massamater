class Staff::InventoryExceptionsController < Staff::BaseController
  def create
    @exception = ProductException.new(build_exception_attrs)
    if @exception.save
      redirect_to staff_inventory_index_path, notice: t("staff.inventory.exceptions.added")
    else
      load_index_data
      @new_exception = @exception
      render "staff/inventory/index", status: :unprocessable_entity
    end
  end

  def destroy
    ProductException.find(params[:id]).destroy
    redirect_to staff_inventory_index_path, notice: t("staff.inventory.exceptions.removed")
  end

  private

  def build_exception_attrs
    type       = params.dig(:product_exception, :exception_type)
    date       = params.dig(:product_exception, :date)
    product_id = params.dig(:product_exception, :product_id)
    batch_size = params.dig(:product_exception, :batch_size).presence
    ready_time = params.dig(:product_exception, :ready_time_override).presence

    case type
    when "skip"
      { product_id: product_id, date: date,
        skipped: true, added: false, batch_size: nil, ready_time_override: nil }
    when "override"
      { product_id: product_id, date: date,
        skipped: false, added: false,
        batch_size: batch_size,
        ready_time_override: ready_time }
    when "add"
      { product_id: product_id, date: date,
        skipped: false, added: true,
        batch_size: batch_size,
        ready_time_override: nil }
    else
      { product_id: product_id, date: date }
    end
  end

  def load_index_data
    @products      = Product.ordered.with_attached_photo.includes(:product_schedule_days)
    @open_days     = StoreHour.where(open: true).pluck(:day_of_week).map { |d| StoreHour.day_of_weeks[d] }
    @new_product   = Product.new(default_ready_time: "09:00:00")
    @exceptions    = ProductException.where("date >= ?", Date.current)
                                     .order(:date)
                                     .includes(:product)
    @new_exception = @exception
  end
end
