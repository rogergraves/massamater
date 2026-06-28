FactoryBot.define do
  factory :store_exception do
    date   { Faker::Date.forward(days: 30) }
    closed { true }
    reason { "Public holiday" }

    trait :different_hours do
      closed    { false }
      opens_at  { "10:00" }
      closes_at { "14:00" }
    end
  end
end
