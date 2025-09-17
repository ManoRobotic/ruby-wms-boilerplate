FactoryBot.define do
  factory :warehouse do
    sequence(:name) { |n| "Warehouse #{n}" }
    sequence(:location) { |n| "Location #{n}" }
    association :company
  end
end