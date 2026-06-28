FactoryBot.define do
  factory :user do
    phone           { "+351#{Faker::Number.number(digits: 9)}" }
    name            { Faker::Name.name }
    contact_channel { :sms }

    trait :staff do
      password { "password" }
    end

    trait :whatsapp do
      contact_channel { :whatsapp }
    end
  end
end
