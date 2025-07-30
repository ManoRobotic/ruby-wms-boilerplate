class CycleCountItem < ApplicationRecord
  # Associations
  belongs_to :cycle_count
  belongs_to :product

  # Validations
  validates :system_quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :counted_quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :status, presence: true

  # Enums
  STATUSES = %w[pending counted variance_approved].freeze
  validates :status, inclusion: { in: STATUSES }

  # Callbacks
  before_save :calculate_variance

  # Instance methods
  def has_variance?
    variance != 0
  end

  def variance_percentage
    return 0 if system_quantity.zero?
    (variance.to_f / system_quantity * 100).round(2)
  end

  private

  def calculate_variance
    if counted_quantity.present?
      self.variance = counted_quantity - system_quantity
    end
  end
end
