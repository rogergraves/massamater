class Staff::ProductsController < Staff::BaseController
  def index
    @products  = Product.ordered.includes(:product_schedule_days)
    @open_days = StoreHour.where(open: true).pluck(:day_of_week)
    @new_product = Product.new
  end

  def create
    @product = Product.new(product_params)
    if @product.save
      save_schedule(@product)
      redirect_to staff_products_path, notice: t("staff.products.created")
    else
      @products  = Product.ordered.includes(:product_schedule_days)
      @open_days = StoreHour.where(open: true).pluck(:day_of_week)
      @new_product = @product
      @show_new_form = true
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @product = Product.find(params[:id])
    if @product.update(product_params)
      save_schedule(@product)
      redirect_to staff_products_path, notice: t("staff.products.saved")
    else
      @products  = Product.ordered.includes(:product_schedule_days)
      @open_days = StoreHour.where(open: true).pluck(:day_of_week)
      @new_product = Product.new
      @editing_product_id = @product.id
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    Product.find(params[:id]).destroy
    redirect_to staff_products_path, notice: t("staff.products.deleted")
  end

  private

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
