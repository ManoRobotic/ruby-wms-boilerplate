FactoryBot.define do
  factory :wave do
    name { "MyString" }
    warehouse { nil }
    status { "MyString" }
    wave_type { "MyString" }
    priority { 1 }
    planned_start_time { "2025-08-01 20:44:57" }
    actual_start_time { "2025-08-01 20:44:57" }
    actual_end_time { "2025-08-01 20:44:57" }
    total_orders { 1 }
    total_items { 1 }
    strategy { "MyString" }
    notes { "MyText" }
  end
end
