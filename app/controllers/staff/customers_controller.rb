module Staff
  class CustomersController < Staff::BaseController
    def lookup
      user = User.find_by(phone: params[:phone])
      if user
        last_res = user.reservations.order(created_at: :desc).first
        source_name = last_res ? last_res.source : "phone"

        reservation = nil
        if params[:date].present?
          res = user.reservations.find_by(date: params[:date])
          if res
            items = res.reservation_items.each_with_object({}) do |item, h|
              h[item.product_id.to_s] = item.quantity
            end
            reservation = {
              id:          res.id,
              pickup_time: res.pickup_time&.strftime("%H:%M"),
              source:      res.source,
              note:        res.note,
              items:       items
            }
          end
        end

        render json: { found: true, name: user.name, source: source_name, reservation: reservation }
      else
        render json: { found: false, source: "phone" }
      end
    end
  end
end
