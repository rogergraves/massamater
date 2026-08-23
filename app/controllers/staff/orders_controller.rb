module Staff
  class OrdersController < Staff::BaseController
    def new
      today     = Date.current
      requested = params[:date].present? ? Date.parse(params[:date]) : today
      @default_date = DayPresenter.open_on?(requested) ? requested : DayPresenter.next_open_date(from: today)
    rescue ArgumentError
      @default_date = DayPresenter.open_on?(today) ? today : DayPresenter.next_open_date(from: today)
    end

    def products
      return head(:bad_request) unless params[:date].present?
      date = Date.parse(params[:date])
      unless DayPresenter.open_on?(date)
        return render partial: "closed_day", locals: { date: date }
      end
      presenter    = DayPresenter.new(date)
      sold_out_ids = presenter.sold_out_products.map(&:id).to_set
      available    = presenter.available_products.reject { |p| sold_out_ids.include?(p.id) }
      sold_out     = presenter.sold_out_products
      unscheduled  = presenter.unscheduled_products
      render partial: "products", locals: {
        presenter: presenter,
        available: available,
        sold_out: sold_out,
        unscheduled: unscheduled,
        date: date
      }
    rescue ArgumentError, TypeError
      head :bad_request
    end

    def create
      date = Date.parse(reservation_params[:date]) rescue nil
      unless date && DayPresenter.open_on?(date)
        flash.now[:alert] = t("staff.orders.closed_day")
        return render :new, status: :unprocessable_entity
      end

      phone     = reservation_params[:phone].to_s.strip
      name      = reservation_params[:name].to_s.strip.presence
      is_update = false

      ActiveRecord::Base.transaction do
        user = User.find_or_initialize_by(phone: phone)
        user.name = name if user.new_record?
        user.save!

        @reservation = user.reservations.find_or_initialize_by(date: reservation_params[:date])
        is_update    = @reservation.persisted?

        @reservation.assign_attributes(
          pickup_time: reservation_params[:pickup_time].presence,
          source:      reservation_params[:source],
          note:        reservation_params[:note].presence
        )
        @reservation.save!

        @reservation.reservation_items.destroy_all
        (reservation_params[:items] || {}).each do |product_id, qty|
          quantity = qty.to_i
          next if quantity <= 0
          @reservation.reservation_items.create!(product_id: product_id, quantity: quantity)
        end
      end

      redirect_to staff_root_path, notice: t(is_update ? "staff.orders.updated" : "staff.orders.created")
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:error] = e.message
      render :new, status: :unprocessable_entity
    end

    private

    def reservation_params
      params.require(:reservation).permit(
        :phone, :name, :date, :pickup_time, :source, :note,
        items: {}
      )
    end
  end
end
