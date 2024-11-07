class Order < ApplicationRecord
    has_many :order_products, dependent: :destroy
end
