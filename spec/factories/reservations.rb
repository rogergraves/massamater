FactoryBot.define do
  factory :reservation do
    user
    date         { Date.tomorrow }
    pickup_time  { nil }
    note         { nil }
    source       { :online }
    collected_at { nil }
    cancelled    { false }
  end
end
