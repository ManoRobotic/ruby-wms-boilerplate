class CycleCount < ApplicationRecord
  # Associations
  belongs_to :warehouse
  belongs_to :admin
  belongs_to :location
  has_many :cycle_count_items, dependent: :destroy
  has_many :products, through: :cycle_count_items

  # Validations
  validates :status, presence: true
  validates :count_type, presence: true
  validates :scheduled_date, presence: true

  # Enums
  STATUSES = %w[scheduled in_progress completed cancelled].freeze
  COUNT_TYPES = %w[full_count spot_count abc_count].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :count_type, inclusion: { in: COUNT_TYPES }

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :scheduled, -> { where(status: "scheduled") }
  scope :completed, -> { where(status: "completed") }

  # Instance methods
  def display_name
    "#{count_type.humanize} - #{location.coordinate_code}"
  end

  def start!
    update(status: "in_progress")
  end

  def complete!
    update(status: "completed", completed_date: Date.current)
  end

  def all_items_counted?
    cycle_count_items.any? && cycle_count_items.all? { |item| item.counted_quantity.present? }
  end

  def create_variance_adjustments!
    cycle_count_items.each do |item|
      next unless item.has_variance?

      # Create inventory adjustment transaction
      InventoryTransaction.create!(
        warehouse: warehouse,
        location: location,
        product: item.product,
        transaction_type: item.variance > 0 ? "adjustment_in" : "adjustment_out",
        quantity: item.variance.abs,
        admin: admin,
        reason: "Ajuste por conteo cíclico #{display_name}",
        reference: self
      )
    end
  end

  def total_variances
    cycle_count_items.where.not(variance: 0).count
  end

  # Status helper methods
  def scheduled?
    status == "scheduled"
  end

  def in_progress?
    status == "in_progress"
  end

  def completed?
    status == "completed"
  end

  def cancelled?
    status == "cancelled"
  end
end
