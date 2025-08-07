FactoryBot.define do
  factory :notification do
    user { nil }
    title { "MyString" }
    message { "MyText" }
    notification_type { "MyString" }
    read_at { "2025-08-07 05:45:27" }
    data { "MyText" }
  end
end
