FactoryBot.define do
  factory :product do
    name                               { Faker::Food.dish }
    name_en                            { nil }
    default_ready_time                 { "09:00" }
    default_daily_batch_size           { 12 }
    max_reservable_quantity_per_client { nil }
    active                             { true }
    order                              { 0 }
  end
end
