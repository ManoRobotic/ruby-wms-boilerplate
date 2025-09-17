FactoryBot.define do
  factory :warehouse do
    sequence(:name) { |n| "Warehouse #{n}" }
    sequence(:code) { |n| "WH#{n}" }
    address { "123 Warehouse Street" }
    association :company
  end
end