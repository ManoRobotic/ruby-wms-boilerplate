FactoryBot.define do
  factory :company do
    sequence(:name) { |n| "Company #{n}" }
    sequence(:address) { |n| "Address #{n}" }
  end
end