class PickListItem < ApplicationRecord
  # Associations
  belongs_to :pick_list
  belongs_to :product
  belongs_to :location
  has_one :warehouse, through: :pick_list
  has_one :order, through: :pick_list

  # Validations
  validates :quantity_requested, presence: true, numericality: { greater_than: 0 }
  validates :quantity_picked, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validates :sequence, presence: true, numericality: { greater_than: 0 }
  validates :sequence, uniqueness: { scope: :pick_list_id }

  # Custom validation
  validate :quantity_picked_not_exceeding_requested
  validate :sufficient_stock_available

  # Enums
  STATUSES = %w[pending in_progress picked short_picked cancelled].freeze

  validates :status, inclusion: { in: STATUSES }

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :pending, -> { where(status: "pending") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :picked, -> { where(status: "picked") }
  scope :short_picked, -> { where(status: "short_picked") }
  scope :completed, -> { where(status: [ "picked", "short_picked" ]) }
  scope :by_sequence, -> { order(:sequence) }
  scope :by_location_route, -> { joins(location: :zone).order("zones.name, locations.aisle, locations.bay") }

  # Callbacks
  after_update :update_pick_list_counters, if: :quantity_picked_changed?
  after_update :reserve_stock, if: :picked_or_short_picked?
  after_save :update_status_based_on_quantity

  # Instance methods
  def display_name
    "#{product.name} - #{location.coordinate_code}"
  end

  def completion_percentage
    return 0 if quantity_requested.zero?
    (quantity_picked.to_f / quantity_requested * 100).round(2)
  end

  def is_fully_picked?
    quantity_picked >= quantity_requested
  end

  def is_short_picked?
    quantity_picked > 0 && quantity_picked < quantity_requested
  end

  def remaining_quantity
    [ quantity_requested - quantity_picked, 0 ].max
  end

  def variance
    quantity_picked - quantity_requested
  end

  def can_be_picked?
    pending? || in_progress?
  end

  def available_stock
    stock = Stock.find_by(product: product, location: location, size: size)
    return 0 unless stock

    stock.amount - stock.reserved_quantity
  end

  def start_picking!
    return false unless pending?

    update(status: "in_progress")
  end

  def pick!(quantity)
    return false unless can_be_picked?
    return false if quantity <= 0
    return false if quantity > available_stock

    self.quantity_picked = [ quantity, quantity_requested ].min
    save!
  end

  def complete_pick!
    return false unless quantity_picked > 0

    if is_fully_picked?
      update(status: "picked")
    else
      update(status: "short_picked")
    end
  end

  def cancel!
    return false if picked?

    update(status: "cancelled", quantity_picked: 0)
  end

  # Status helper methods
  STATUSES.each do |status_name|
    define_method "#{status_name}?" do
      status == status_name
    end
  end

  # Location and routing helpers
  def zone_name
    location.zone.name
  end

  def coordinate_code
    location.coordinate_code
  end

  def estimated_pick_time
    # Base time + complexity factors
    base_time = 2.minutes

    # Add time based on quantity
    quantity_time = quantity_requested * 30.seconds

    # Add time for location type complexity
    location_complexity = case location.location_type
    when "floor", "bulk" then 1.minute
    when "rack" then 2.minutes
    when "shelf" then 1.5.minutes
    else 1.minute
    end

    base_time + quantity_time + location_complexity
  end

  # Class methods
  def self.create_batch_for_products(pick_list, products_data)
    sequence = pick_list.pick_list_items.maximum(:sequence) || 0

    items = []
    products_data.each do |product_data|
      sequence += 1

      items << new(
        pick_list: pick_list,
        product: product_data[:product],
        location: product_data[:location],
        quantity_requested: product_data[:quantity],
        size: product_data[:size],
        sequence: sequence,
        status: "pending"
      )
    end

    import(items) # Using activerecord-import gem if available, otherwise use create!
    items
  end

  def self.optimize_sequence_by_route(pick_list)
    # Reorganize pick list items by optimal warehouse route
    items = pick_list.pick_list_items.includes(location: :zone)
                    .order("zones.name, locations.aisle, locations.bay, locations.level")

    items.each_with_index do |item, index|
      item.update_column(:sequence, index + 1)
    end
  end

  def self.daily_pick_performance(date = Date.current)
    daily_items = joins(:pick_list)
                    .where(pick_lists: { created_at: date.beginning_of_day..date.end_of_day })

    {
      total_items: daily_items.count,
      picked_items: daily_items.picked.count,
      short_picked_items: daily_items.short_picked.count,
      cancelled_items: daily_items.where(status: "cancelled").count,
      pick_accuracy: daily_items.picked.count.to_f / daily_items.completed.count * 100,
      total_quantity_requested: daily_items.sum(:quantity_requested),
      total_quantity_picked: daily_items.sum(:quantity_picked)
    }
  end

  private

  def quantity_picked_not_exceeding_requested
    return unless quantity_picked && quantity_requested

    if quantity_picked > quantity_requested
      errors.add(:quantity_picked, "cannot exceed quantity requested")
    end
  end

  def sufficient_stock_available
    return unless quantity_picked && quantity_picked > 0

    if quantity_picked > available_stock
      errors.add(:quantity_picked, "exceeds available stock (#{available_stock})")
    end
  end

  def update_pick_list_counters
    pick_list.reload
    pick_list.update_columns(
      total_items: pick_list.pick_list_items.sum(:quantity_requested),
      picked_items: pick_list.pick_list_items.sum(:quantity_picked)
    )
  end

  def reserve_stock
    return unless quantity_picked > 0

    stock = Stock.find_by(
      product: product,
      location: location,
      size: size
    )

    return unless stock

    # Reserve the picked quantity
    reserved_qty = stock.reserved_quantity + quantity_picked
    stock.update!(reserved_quantity: [ reserved_qty, stock.amount ].min)
  end

  def update_status_based_on_quantity
    return unless quantity_picked_changed?

    if quantity_picked.zero?
      self.status = "pending" unless cancelled?
    elsif quantity_picked >= quantity_requested
      self.status = "picked"
    elsif quantity_picked > 0
      self.status = "short_picked"
    end
  end

  def picked_or_short_picked?
    status_changed? && (picked? || short_picked?)
  end
end
