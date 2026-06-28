FactoryBot.define do
  factory :reservation_item do
    reservation
    product
    quantity { 1 }
  end
end
