class Company < ApplicationRecord
  has_many :production_orders
  has_many :warehouses
  has_many :admins
end
