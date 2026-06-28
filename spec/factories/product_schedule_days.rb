FactoryBot.define do
  factory :product_schedule_day do
    product
    day_of_week { :tuesday }
  end
end
