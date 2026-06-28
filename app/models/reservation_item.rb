class ReservationItem < ApplicationRecord
  belongs_to :reservation
  belongs_to :product

  validates :quantity,   numericality: { only_integer: true, greater_than: 0 }
  validates :product_id, uniqueness: { scope: :reservation_id }
end
