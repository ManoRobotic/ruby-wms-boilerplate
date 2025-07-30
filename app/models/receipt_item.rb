class ReceiptItem < ApplicationRecord
  # Associations
  belongs_to :receipt
  belongs_to :product
  belongs_to :location

  # Validations
  validates :expected_quantity, presence: true, numericality: { greater_than: 0 }
  validates :received_quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :unit_cost, numericality: { greater_than: 0 }, allow_nil: true
  validates :status, presence: true

  # Enums
  STATUSES = %w[pending receiving completed variance].freeze
  validates :status, inclusion: { in: STATUSES }

  # Instance methods
  def variance
    received_quantity - expected_quantity
  end

  def has_variance?
    variance != 0
  end
end
