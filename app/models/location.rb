class Location < ApplicationRecord
  # Associations
  belongs_to :zone
  has_one :warehouse, through: :zone
  has_many :stocks, dependent: :destroy
  has_many :products, through: :stocks
  has_many :tasks, dependent: :destroy
  has_many :pick_list_items, dependent: :destroy
  has_many :inventory_transactions, dependent: :destroy
  has_many :receipt_items, dependent: :destroy
  has_many :cycle_counts, dependent: :destroy

  # Validations
  validates :aisle, presence: true, length: { maximum: 10 }
  validates :bay, presence: true, length: { maximum: 10 }
  validates :level, presence: true, length: { maximum: 10 }
  validates :position, presence: true, length: { maximum: 10 }
  validates :barcode, length: { maximum: 50 }, uniqueness: { case_sensitive: false }, allow_blank: true
  validates :location_type, presence: true
  validates :capacity, presence: true, numericality: { greater_than: 0 }
  validates :current_volume, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :active, inclusion: { in: [ true, false ] }

  # Unique constraint for coordinates within a zone
  validates :aisle, uniqueness: {
    scope: [ :zone_id, :bay, :level, :position ],
    message: "Location coordinates must be unique within zone"
  }

  # Enums for location types
  LOCATION_TYPES = %w[
    bin
    shelf
    floor
    rack
    bulk
    pick_face
    reserve
    staging
    dock
    quarantine
  ].freeze

  validates :location_type, inclusion: { in: LOCATION_TYPES }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :by_type, ->(type) { where(location_type: type) }
  scope :by_zone, ->(zone) { where(zone: zone) }
  scope :by_warehouse, ->(warehouse) { joins(:zone).where(zones: { warehouse: warehouse }) }
  scope :available, -> { active.where("current_volume < capacity") }
  scope :at_capacity, -> { where("current_volume >= capacity") }
  scope :empty, -> { where(current_volume: 0) }
  scope :with_stock, -> { joins(:stocks).where("stocks.amount > 0").distinct }
  scope :search, ->(term) { where("CONCAT(aisle, '-', bay, '-', level, '-', position) ILIKE ? OR barcode ILIKE ?", "%#{term}%", "%#{term}%") }

  # Callbacks
  before_validation :normalize_barcode
  before_save :check_capacity_constraints

  # Instance methods
  def coordinate_code
    "#{aisle}-#{bay}-#{level}-#{position}"
  end

  def full_code
    "#{zone.warehouse.code}-#{zone.code}-#{coordinate_code}"
  end

  def display_name
    barcode.present? ? "#{coordinate_code} (#{barcode})" : coordinate_code
  end

  def available_capacity
    capacity - current_volume
  end

  def utilization_percentage
    return 0 if capacity.zero?
    (current_volume.to_f / capacity * 100).round(2)
  end

  def can_accommodate?(quantity = 1)
    available_capacity >= quantity
  end

  def current_products
    products.joins(:stocks).where(stocks: { location: self, amount: 1.. }).distinct
  end

  def total_stock_quantity
    stocks.sum(:amount)
  end

  def reserved_quantity
    stocks.sum(:reserved_quantity)
  end

  def available_quantity
    total_stock_quantity - reserved_quantity
  end

  def current_stock_value
    stocks.joins(:product).sum("stocks.amount * products.price")
  end

  def pending_tasks
    tasks.where(status: "pending")
  end

  def last_inventory_transaction
    inventory_transactions.order(created_at: :desc).first
  end

  def needs_cycle_count?
    last_count = cycle_counts.completed.order(completed_date: :desc).first
    return true unless last_count

    last_count.completed_date < 30.days.ago
  end

  # Movement methods
  def add_stock(product, quantity, options = {})
    return false unless can_accommodate?(quantity)

    stock = stocks.find_or_initialize_by(
      product: product,
      size: options[:size],
      batch_number: options[:batch_number]
    )

    stock.amount = (stock.amount || 0) + quantity
    stock.unit_cost = options[:unit_cost] if options[:unit_cost]
    stock.expiry_date = options[:expiry_date] if options[:expiry_date]
    stock.received_date = options[:received_date] || Date.current

    if stock.save
      update_volume(quantity)
      true
    else
      false
    end
  end

  def remove_stock(product, quantity, options = {})
    stock = stocks.find_by(
      product: product,
      size: options[:size],
      batch_number: options[:batch_number]
    )

    return false unless stock && stock.amount >= quantity

    stock.amount -= quantity

    if stock.amount.zero?
      stock.destroy
    else
      stock.save
    end

    update_volume(-quantity)
    true
  end

  # Location type helper methods
  LOCATION_TYPES.each do |type|
    define_method "#{type}?" do
      location_type == type
    end
  end

  # Class methods
  def self.find_by_barcode(barcode)
    find_by(barcode: barcode&.upcase&.strip)
  end

  def self.find_by_coordinates(zone, aisle, bay, level, position)
    find_by(zone: zone, aisle: aisle, bay: bay, level: level, position: position)
  end

  def self.suggest_for_product(product, quantity = 1)
    available
      .joins(:zone)
      .where(zones: { zone_type: "storage" })
      .where("capacity - current_volume >= ?", quantity)
      .order(:current_volume)
      .limit(5)
  end

  private

  def normalize_barcode
    self.barcode = barcode&.upcase&.strip if barcode.present?
  end

  def check_capacity_constraints
    if current_volume > capacity
      errors.add(:current_volume, "cannot exceed capacity")
      throw :abort
    end
  end

  def update_volume(quantity_change)
    new_volume = current_volume + quantity_change
    update_column(:current_volume, [ new_volume, 0 ].max)
  end
end
