FactoryBot.define do
  factory :production_order do
    order_number { "MyString" }
    status { "MyString" }
    priority { "MyString" }
    warehouse { nil }
    product { nil }
    quantity_requested { 1 }
    quantity_produced { 1 }
    start_date { "2025-08-07 06:05:46" }
    end_date { "2025-08-07 06:05:46" }
    estimated_completion { "2025-08-07 06:05:46" }
    actual_completion { "2025-08-07 06:05:46" }
    notes { "MyText" }
  end
end
