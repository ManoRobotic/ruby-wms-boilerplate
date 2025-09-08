class Product < ApplicationRecord
  has_many_attached :images do |attachable|
      attachable.variant :thumb, resize_to_limit: [ 50, 50 ]
      attachable.variant :medium, resize_to_limit: [ 250, 250 ]
      attachable.variant :large, resize_to_limit: [ 500, 500 ]
  end

  # Original associations
  belongs_to :category
  belongs_to :company, optional: true
  has_many :stocks, dependent: :destroy
  has_many :order_products, dependent: :destroy

  # WMS associations
  has_many :locations, through: :stocks
  has_many :tasks, dependent: :destroy
  has_many :pick_list_items, dependent: :destroy
  has_many :pick_lists, through: :pick_list_items
  has_many :inventory_transactions, dependent: :destroy
  has_many :receipt_items, dependent: :destroy
  has_many :cycle_count_items, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :description, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :active, inclusion: { in: [ true, false ] }

  # WMS validations
  validates :sku, length: { maximum: 50 }, uniqueness: { case_sensitive: false }, allow_blank: true
  validates :barcode, length: { maximum: 50 }, uniqueness: { case_sensitive: false }, allow_blank: true
  validates :weight, numericality: { greater_than: 0 }, allow_nil: true
  validates :reorder_point, numericality: { greater_than_or_equal_to: 0 }
  validates :max_stock_level, numericality: { greater_than: 0 }
  validates :batch_tracking, inclusion: { in: [ true, false ] }
  validates :unit_of_measure, presence: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_company, ->(company) { where(company: company) }
  scope :with_stock, -> { joins(:stocks).where(stocks: { amount: 1.. }).distinct }
  scope :without_stock, -> { left_joins(:stocks).where(stocks: { id: nil }).or(joins(:stocks).where(stocks: { amount: 0 })) }
  scope :price_range, ->(min, max) { where(price: min..max) }
  scope :search, ->(term) { where("name ILIKE ? OR description ILIKE ? OR sku ILIKE ? OR barcode ILIKE ?", "%#{term}%", "%#{term}%", "%#{term}%", "%#{term}%") }
  scope :recent, -> { order(created_at: :desc) }
  scope :popular, -> { joins(:order_products).group(:id).order("COUNT(order_products.id) DESC") }

  # WMS scopes
  scope :with_sku, -> { where.not(sku: [ nil, "" ]) }
  scope :with_barcode, -> { where.not(barcode: [ nil, "" ]) }
  scope :batch_tracked, -> { where(batch_tracking: true) }
  scope :low_stock, -> { joins(:stocks).group(:id).having("SUM(stocks.amount - stocks.reserved_quantity) <= products.reorder_point") }
  scope :overstock, -> { joins(:stocks).group(:id).having("SUM(stocks.amount) > products.max_stock_level") }
  scope :by_warehouse, ->(warehouse) { joins(stocks: { location: { zone: :warehouse } }).where(warehouses: { id: warehouse }).distinct }

  # Instance methods
  def in_stock?
    stocks.sum(:amount) > 0
  end

  def total_stock
    stocks.sum(:amount)
  end

  def available_sizes
    stocks.where("amount > 0").pluck(:size).uniq
  end

  def stock_for_size(size)
    stocks.find_by(size: size)&.amount || 0
  end

  def price_with_currency
    "#{price} MXN"
  end

  def main_image
    images.attached? ? images.first : nil
  end

  def can_be_ordered?(size, quantity = 1)
    return false unless active?
    available_stock_for_size(size) >= quantity
  end

  def available_stock_for_size(size)
    stocks.where(size: size).sum("amount - reserved_quantity")
  end

  # WMS instance methods
  def available_stock_by_location
    stocks.joins(:location)
          .select("locations.*, SUM(stocks.amount - stocks.reserved_quantity) as available_qty")
          .group("locations.id")
          .having("SUM(stocks.amount - stocks.reserved_quantity) > 0")
  end

  def total_reserved_quantity
    stocks.sum(:reserved_quantity)
  end

  def available_quantity
    total_stock - total_reserved_quantity
  end

  def stock_by_warehouse(warehouse = nil)
    query = stocks.joins(location: { zone: :warehouse })
    query = query.where(warehouses: { id: warehouse }) if warehouse
    query.sum(:amount)
  end

  def needs_replenishment?
    available_quantity <= reorder_point
  end

  def is_overstocked?
    total_stock > max_stock_level
  end

  def recent_movements(days = 30)
    inventory_transactions.where(created_at: days.days.ago..Time.current)
                         .order(created_at: :desc)
  end

  def average_cost
    return 0 if stocks.empty?

    stocks.where.not(unit_cost: nil).average(:unit_cost) || price
  end

  def locations_with_stock
    locations.joins(:stocks)
            .where("stocks.amount > stocks.reserved_quantity")
            .distinct
  end

  def generate_sku
    return if sku.present?

    base = name.gsub(/[^a-zA-Z0-9]/, "").upcase[0..5]
    suffix = SecureRandom.hex(3).upcase
    self.sku = "#{base}#{suffix}"
  end

  def generate_barcode
    return if barcode.present?

    # Simple EAN-13 like format
    self.barcode = "#{category_id.to_s.last(3)}#{id.to_s.last(6)}#{SecureRandom.hex(2)}".upcase
  end

  def dimensions_display
    return "Not specified" if dimensions.empty?

    "L: #{dimensions['length']}cm × W: #{dimensions['width']}cm × H: #{dimensions['height']}cm"
  end

  # Class methods
  def self.low_stock(threshold = 5)
    joins(:stocks).where("stocks.amount <= ?", threshold).distinct
  end

  def self.best_selling(limit = 10)
    joins(:order_products)
      .group(:id)
      .order("SUM(order_products.quantity) DESC")
      .limit(limit)
  end

  def self.find_by_sku(sku)
    find_by(sku: sku&.upcase&.strip)
  end

  def self.find_by_barcode(barcode)
    find_by(barcode: barcode&.upcase&.strip)
  end

  def self.inventory_valuation(warehouse = nil)
    query = joins(stocks: { location: { zone: :warehouse } })
    query = query.where(warehouses: { id: warehouse }) if warehouse

    query.sum("stocks.amount * COALESCE(stocks.unit_cost, products.price)")
  end

  def self.abc_analysis(warehouse = nil)
    # Simple ABC analysis based on inventory value
    query = joins(stocks: { location: { zone: :warehouse } })
    query = query.where(warehouses: { id: warehouse }) if warehouse

    products_value = query.group(:id)
                         .sum("stocks.amount * COALESCE(stocks.unit_cost, products.price)")
                         .sort_by { |_, value| -value }

    total_value = products_value.values.sum
    return {} if total_value.zero?

    cumulative_percentage = 0
    abc_classification = {}

    products_value.each do |product_id, value|
      percentage = (value / total_value) * 100
      cumulative_percentage += percentage

      classification = if cumulative_percentage <= 70
                        "A"
      elsif cumulative_percentage <= 90
                        "B"
      else
                        "C"
      end

      abc_classification[product_id] = {
        classification: classification,
        value: value,
        percentage: percentage.round(2)
      }
    end

    abc_classification
  end
end
