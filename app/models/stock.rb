class Stock < ApplicationRecord
  # Associations
  belongs_to :product
  belongs_to :location, optional: true
  has_one :zone, through: :location
  has_one :warehouse, through: :zone
  has_many :inventory_transactions, through: :product

  # Validations
  validates :size, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :reserved_quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :unit_cost, numericality: { greater_than: 0 }, allow_nil: true
  validates :batch_number, length: { maximum: 50 }

  # Custom validations
  validate :reserved_not_exceeding_amount
  validate :expiry_date_in_future, if: :expiry_date?
  validate :batch_required_if_product_batch_tracked

  # Scopes
  scope :with_stock, -> { where("amount > 0") }
  scope :available, -> { where("amount > reserved_quantity") }
  scope :reserved, -> { where("reserved_quantity > 0") }
  scope :by_location, ->(location) { where(location: location) }
  scope :by_warehouse, ->(warehouse) { joins(location: { zone: :warehouse }).where(warehouses: { id: warehouse }) }
  scope :by_product, ->(product) { where(product: product) }
  scope :by_batch, ->(batch) { where(batch_number: batch) }
  scope :expiring_soon, ->(days = 30) { where("expiry_date <= ?", days.days.from_now) }
  scope :expired, -> { where("expiry_date < ?", Date.current) }
  scope :with_cost, -> { where.not(unit_cost: nil) }
  scope :fifo_order, -> { order(:received_date, :created_at) }
  scope :lifo_order, -> { order(received_date: :desc, created_at: :desc) }
  scope :fefo_order, -> { order(:expiry_date, :received_date) } # First Expired, First Out

  # Instance methods
  def available_quantity
    amount - reserved_quantity
  end

  def is_available?
    available_quantity > 0
  end

  def is_expired?
    expiry_date.present? && expiry_date < Date.current
  end

  def is_expiring_soon?(days = 30)
    expiry_date.present? && expiry_date <= days.days.from_now
  end

  def days_until_expiry
    return nil unless expiry_date
    (expiry_date - Date.current).to_i
  end

  def total_value
    return 0 unless unit_cost
    amount * unit_cost
  end

  def available_value
    return 0 unless unit_cost
    available_quantity * unit_cost
  end

  def reserve!(quantity)
    return false if quantity > available_quantity

    increment!(:reserved_quantity, quantity)
    true
  end

  def unreserve!(quantity = nil)
    qty_to_unreserve = quantity || reserved_quantity
    qty_to_unreserve = [ qty_to_unreserve, reserved_quantity ].min

    decrement!(:reserved_quantity, qty_to_unreserve)
    qty_to_unreserve
  end

  def consume_reserved!(quantity)
    return false if quantity > reserved_quantity

    decrement!(:reserved_quantity, quantity)
    decrement!(:amount, quantity)

    destroy if amount.zero?
    true
  end

  def location_display
    location&.coordinate_code || "No Location"
  end

  def batch_display
    batch_number.presence || "No Batch"
  end

  def expiry_display
    return "No Expiry" unless expiry_date

    status = if is_expired?
              "(EXPIRED)"
    elsif is_expiring_soon?
              "(EXPIRING SOON)"
    else
              ""
    end

    "#{expiry_date.strftime('%Y-%m-%d')} #{status}".strip
  end

  def age_in_days
    return 0 unless received_date
    (Date.current - received_date).to_i
  end

  # Class methods
  def self.total_inventory_value
    with_cost.sum("amount * unit_cost")
  end

  def self.available_inventory_value
    with_cost.sum("(amount - reserved_quantity) * unit_cost")
  end

  def self.allocate_for_pick(product, size, quantity_needed, allocation_method = :fifo)
    available_stocks = where(product: product, size: size)
                      .available
                      .where("amount > reserved_quantity")

    # Apply allocation method
    case allocation_method
    when :fifo
      available_stocks = available_stocks.fifo_order
    when :lifo
      available_stocks = available_stocks.lifo_order
    when :fefo
      available_stocks = available_stocks.fefo_order
    end

    allocations = []
    remaining_quantity = quantity_needed

    available_stocks.each do |stock|
      break if remaining_quantity <= 0

      allocatable_qty = [ stock.available_quantity, remaining_quantity ].min

      if allocatable_qty > 0
        allocations << {
          stock: stock,
          quantity: allocatable_qty,
          location: stock.location
        }

        remaining_quantity -= allocatable_qty
      end
    end

    {
      allocations: allocations,
      allocated_quantity: quantity_needed - remaining_quantity,
      remaining_quantity: remaining_quantity,
      fully_allocated: remaining_quantity.zero?
    }
  end

  def self.expiry_report(days = 30)
    {
      expiring_soon: expiring_soon(days).group(:product_id).sum(:amount),
      expired: expired.group(:product_id).sum(:amount),
      total_expiring_value: expiring_soon(days).with_cost.sum("amount * unit_cost"),
      total_expired_value: expired.with_cost.sum("amount * unit_cost")
    }
  end

  def self.consolidation_opportunities
    # Find products with multiple small stocks in same location
    where("amount < 10")
      .group(:product_id, :location_id, :size)
      .having("COUNT(*) > 1")
      .count
  end

  private

  def reserved_not_exceeding_amount
    return unless reserved_quantity && amount

    if reserved_quantity > amount
      errors.add(:reserved_quantity, "cannot exceed available amount")
    end
  end

  def expiry_date_in_future
    if expiry_date < Date.current
      errors.add(:expiry_date, "cannot be in the past")
    end
  end

  def batch_required_if_product_batch_tracked
    return unless product&.batch_tracking?

    if batch_number.blank?
      errors.add(:batch_number, "is required for batch-tracked products")
    end
  end
end
