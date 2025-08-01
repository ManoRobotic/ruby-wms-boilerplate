class Receipt < ApplicationRecord
  # Associations
  belongs_to :warehouse
  belongs_to :admin
  has_many :receipt_items, dependent: :destroy
  has_many :products, through: :receipt_items
  has_many :inventory_transactions, as: :reference, dependent: :destroy

  # Validations
  validates :supplier_name, presence: true, length: { maximum: 100 }
  validates :reference_number, presence: true, uniqueness: { scope: :warehouse_id }
  validates :status, presence: true
  validates :total_items, numericality: { greater_than_or_equal_to: 0 }
  validates :received_items, numericality: { greater_than_or_equal_to: 0 }

  # Set default values
  after_initialize :set_defaults

  private

  def set_defaults
    self.received_items ||= 0 if new_record?
  end

  # Enums
  STATUSES = %w[scheduled receiving completed cancelled].freeze
  validates :status, inclusion: { in: STATUSES }

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :by_warehouse, ->(warehouse) { where(warehouse: warehouse) }
  scope :scheduled, -> { where(status: "scheduled") }
  scope :receiving, -> { where(status: "receiving") }
  scope :completed, -> { where(status: "completed") }
  scope :overdue, -> { where("expected_date < ? AND status != ?", Date.current, "completed") }

  # Callbacks
  before_validation :generate_reference_number, on: :create
  after_create :create_receipt_items

  # Instance methods
  def display_name
    "#{reference_number} - #{supplier_name}"
  end

  def completion_percentage
    return 0 if total_items.zero?
    (received_items.to_f / total_items * 100).round(2)
  end

  def is_overdue?
    expected_date < Date.current && !completed?
  end

  def start_receiving!
    return false unless status == "scheduled"
    update(status: "receiving")
  end

  def complete!
    return false unless status == "receiving"
    update(status: "completed", received_date: Date.current)
  end

  def all_items_received?
    receipt_items.any? && receipt_items.all? { |item| item.received_quantity.present? && item.received_quantity > 0 }
  end

  def items_completion_percentage
    return 0 if receipt_items.empty?
    
    total_expected = receipt_items.sum(:expected_quantity)
    total_received = receipt_items.sum { |item| item.received_quantity || 0 }
    
    return 0 if total_expected.zero?
    (total_received.to_f / total_expected * 100).round(2)
  end

  private

  def generate_reference_number
    self.reference_number ||= "RCP#{Date.current.strftime('%Y%m%d')}#{SecureRandom.hex(3).upcase}"
  end

  def create_receipt_items
    # This would be implemented based on expected items
    # For now, keeping it simple
  end
end
