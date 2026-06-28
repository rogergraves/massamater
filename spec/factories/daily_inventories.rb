FactoryBot.define do
  factory :daily_inventory do
    product
    date               { Date.today }
    batch_size         { 12 }
    ready_time_override { nil }
    skipped            { false }
    added              { false }
  end
end
