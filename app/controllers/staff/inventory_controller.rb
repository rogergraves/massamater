class Staff::InventoryController < Staff::BaseController
  before_action :set_product, only: [:update, :destroy]

  def index
    load_index_data
  end

  def create
    @product = Product.new(product_params)
    ApplicationRecord.transaction do
      @product.save!
      save_schedule(@product)
    end
    redirect_to staff_inventory_index_path, notice: t("staff.inventory.created")
  rescue ActiveRecord::RecordInvalid
    load_index_data
    @new_product    = @product
    @show_new_form  = true
    render :index, status: :unprocessable_entity
  end

  def update
    ApplicationRecord.transaction do
      @product.update!(product_params)
      save_schedule(@product)
    end
    redirect_to staff_inventory_index_path, notice: t("staff.inventory.saved")
  rescue ActiveRecord::RecordInvalid
    load_index_data
    @editing_product_id = @product.id
    render :index, status: :unprocessable_entity
  end

  def destroy
    @product.destroy
    redirect_to staff_inventory_index_path, notice: t("staff.inventory.deleted")
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def load_index_data
    @products    = Product.ordered.with_attached_photo.includes(:product_schedule_days)
    @open_days   = StoreHour.where(open: true).pluck(:day_of_week).map { |d| StoreHour.day_of_weeks[d] }
    @new_product = Product.new(default_ready_time: "09:00:00")
    @exceptions  = ProductException.where("date >= ?", Date.current)
                                   .order(:date)
                                   .includes(:product)
    @new_exception = ProductException.new(date: Date.current)
  end

  def product_params
    params.require(:product).permit(
      :name, :name_en, :default_ready_time, :default_daily_batch_size,
      :max_reservable_quantity_per_client, :active, :order, :photo
    )
  end

  def save_schedule(product)
    selected = (params[:day_of_week] || []).map(&:to_i)
    product.product_schedule_days.where.not(day_of_week: selected).destroy_all
    selected.each { |day| product.product_schedule_days.find_or_create_by!(day_of_week: day) }
  end
end
