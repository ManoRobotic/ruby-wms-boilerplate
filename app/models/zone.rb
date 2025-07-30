class Zone < ApplicationRecord
  # Associations
  belongs_to :warehouse
  has_many :locations, dependent: :destroy
  has_many :cycle_counts, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :code, presence: true, length: { minimum: 2, maximum: 20 }
  validates :code, uniqueness: { scope: :warehouse_id, case_sensitive: false }
  validates :zone_type, presence: true, length: { maximum: 50 }
  validates :description, length: { maximum: 1000 }

  # Enums for zone types
  ZONE_TYPES = %w[
    receiving
    storage
    picking
    packing
    shipping
    returns
    quarantine
    bulk
    general
  ].freeze

  validates :zone_type, inclusion: { in: ZONE_TYPES }

  # Scopes
  scope :by_type, ->(type) { where(zone_type: type) }
  scope :by_warehouse, ->(warehouse) { where(warehouse: warehouse) }
  scope :search, ->(term) { where("name ILIKE ? OR code ILIKE ?", "%#{term}%", "%#{term}%") }
  scope :with_available_locations, -> { joins(:locations).where("locations.current_volume < locations.capacity").distinct }

  # Callbacks
  before_validation :normalize_code

  # Instance methods
  def full_code
    "#{warehouse.code}-#{code}"
  end

  def total_locations
    locations.count
  end

  def available_locations
    locations.active.where("current_volume < capacity")
  end

  def utilization_percentage
    return 0 if locations.empty?

    total_capacity = locations.sum(:capacity)
    current_usage = locations.sum(:current_volume)

    return 0 if total_capacity.zero?

    (current_usage.to_f / total_capacity * 100).round(2)
  end

  def current_stock_value
    stocks = Stock.joins(:location).where(locations: { zone: self })
    stocks.joins(:product).sum("stocks.amount * products.price")
  end

  def pending_cycle_counts
    cycle_counts.where(status: "pending")
  end

  # Zone type helper methods
  def receiving_zone?
    zone_type == "receiving"
  end

  def storage_zone?
    zone_type == "storage"
  end

  def picking_zone?
    zone_type == "picking"
  end

  def packing_zone?
    zone_type == "packing"
  end

  def shipping_zone?
    zone_type == "shipping"
  end

  # Class methods
  def self.receiving_zones
    where(zone_type: "receiving")
  end

  def self.storage_zones
    where(zone_type: "storage")
  end

  def self.picking_zones
    where(zone_type: "picking")
  end

  def self.by_warehouse_code(warehouse_code)
    joins(:warehouse).where(warehouses: { code: warehouse_code })
  end

  private

  def normalize_code
    self.code = code&.upcase&.strip
  end
end
