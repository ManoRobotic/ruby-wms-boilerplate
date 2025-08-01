class Warehouse < ApplicationRecord
  # Associations
  has_many :zones, dependent: :destroy
  has_many :locations, through: :zones
  has_many :tasks, dependent: :destroy
  has_many :pick_lists, dependent: :destroy
  has_many :inventory_transactions, dependent: :destroy
  has_many :receipts, dependent: :destroy
  has_many :cycle_counts, dependent: :destroy
  has_many :shipments, dependent: :destroy
  has_many :orders, dependent: :nullify

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :code, presence: true, length: { minimum: 2, maximum: 20 },
            uniqueness: { case_sensitive: false }
  validates :address, presence: true, length: { minimum: 10, maximum: 500 }
  validates :active, inclusion: { in: [ true, false ] }

  # Set default values
  before_validation :set_default_contact_info

  private

  def set_default_contact_info
    if contact_info.blank?
      self.contact_info = {}
    elsif contact_info.is_a?(String)
      begin
        self.contact_info = JSON.parse(contact_info)
      rescue JSON::ParserError
        self.contact_info = { "info" => contact_info }
      end
    end
  end


  public

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :by_code, ->(code) { where(code: code) }
  scope :search, ->(term) { where("name ILIKE ? OR code ILIKE ?", "%#{term}%", "%#{term}%") }

  # Callbacks
  before_validation :normalize_code
  before_save :ensure_contact_info_structure

  # Instance methods
  def total_locations
    locations.count
  end

  def available_locations
    locations.active.where("current_volume < capacity")
  end

  def current_inventory_value
    inventory_transactions
      .where(transaction_type: [ "receipt", "adjustment_in" ])
      .joins(:product)
      .sum("inventory_transactions.quantity * COALESCE(inventory_transactions.unit_cost, products.price)")
  end

  def pending_tasks_count
    tasks.where(status: "pending").count
  end

  def daily_transactions(date = Date.current)
    inventory_transactions.where(created_at: date.beginning_of_day..date.end_of_day)
  end

  def utilization_percentage
    return 0 if locations.empty?

    total_capacity = locations.sum(:capacity)
    current_usage = locations.sum(:current_volume)

    return 0 if total_capacity.zero?

    (current_usage.to_f / total_capacity * 100).round(2)
  end

  def low_stock_products(threshold = 10)
    Product.joins(stocks: :location)
           .where(locations: { zone: zones })
           .group("products.id")
           .having("SUM(stocks.amount - stocks.reserved_quantity) <= ?", threshold)
  end

  def active_pick_lists
    pick_lists.where(status: [ "pending", "in_progress" ])
  end

  # Class methods
  def self.main_warehouse
    active.first
  end

  def self.with_available_capacity
    joins(:locations)
      .where("locations.current_volume < locations.capacity")
      .distinct
  end

  private

  def normalize_code
    self.code = code&.upcase&.strip
  end

  def ensure_contact_info_structure
    self.contact_info ||= {}
    defaults = {
      "phone" => "",
      "email" => "",
      "manager" => "",
      "hours" => ""
    }
    self.contact_info = defaults.merge(contact_info)
  end
end
