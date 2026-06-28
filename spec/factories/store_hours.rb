FactoryBot.define do
  factory :store_hour do
    day_of_week { :tuesday }
    open        { true }
    opens_at    { "08:00" }
    closes_at   { "18:00" }

    trait :closed do
      open      { false }
      opens_at  { nil }
      closes_at { nil }
    end
  end
end
