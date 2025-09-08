class Category < ApplicationRecord
    belongs_to :company
    has_one_attached :image do |attachable|
        attachable.variant :thumb, resize_to_limit: [ 50, 50 ]
    end

    has_many :products, dependent: :destroy

    validates :name, presence: true
    validates :description, presence: true
end
