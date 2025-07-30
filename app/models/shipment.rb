class Shipment < ApplicationRecord
  # Associations
  belongs_to :order
  belongs_to :warehouse
  belongs_to :admin

  # Validations
  validates :status, presence: true
  validates :tracking_number, uniqueness: { case_sensitive: false }, allow_blank: true

  # Enums
  STATUSES = %w[preparing shipped in_transit delivered returned].freeze
  validates :status, inclusion: { in: STATUSES }

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :shipped, -> { where(status: "shipped") }
  scope :delivered, -> { where(status: "delivered") }

  # Instance methods
  def display_name
    "#{tracking_number || id} - Order #{order.display_number}"
  end

  def ship!
    update(status: "shipped", shipped_date: Date.current)
  end

  def deliver!
    update(status: "delivered", delivered_date: Date.current)
  end
end
