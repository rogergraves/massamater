FactoryBot.define do
  factory :product_exception do
    product
    date                { Date.today }
    batch_size          { 12 }
    ready_time_override { nil }
    skipped             { false }
    added               { false }

    trait :skip do
      skipped    { true }
      batch_size { nil }
    end

    trait :override do
      batch_size { 20 }
    end

    trait :added do
      added      { true }
      batch_size { 8 }
    end
  end
end
