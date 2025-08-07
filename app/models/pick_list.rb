class PickList < ApplicationRecord
  # Associations
  belongs_to :admin
  belongs_to :order
  belongs_to :warehouse
  belongs_to :wave, optional: true
  has_many :pick_list_items, dependent: :destroy
  has_many :products, through: :pick_list_items
  has_many :locations, through: :pick_list_items

  # Validations
  validates :status, presence: true
  validates :priority, presence: true
  validates :total_items, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :picked_items, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :pick_list_number, presence: true, uniqueness: true

  # Enums
  STATUSES = %w[pending assigned in_progress completed cancelled].freeze
  PRIORITIES = %w[low medium high urgent].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :by_warehouse, ->(warehouse) { where(warehouse: warehouse) }
  scope :by_admin, ->(admin) { where(admin: admin) }
  scope :pending, -> { where(status: "pending") }
  scope :assigned, -> { where(status: "assigned") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :completed, -> { where(status: "completed") }
  scope :active, -> { where(status: [ "pending", "assigned", "in_progress" ]) }
  scope :high_priority, -> { where(priority: [ "high", "urgent" ]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_priority_order, -> { order(Arel.sql("CASE priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END")) }
  scope :overdue, -> { where("started_at < ? AND status NOT IN (?)", 4.hours.ago, [ "completed", "cancelled" ]) }

  # Callbacks
  before_validation :generate_pick_list_number, on: :create
  before_save :update_progress_counters
  after_create :create_pick_list_items
  after_update :update_order_fulfillment_status

  # Instance methods
  def display_name
    "#{pick_list_number} - Order ##{order.id}"
  end

  def completion_percentage
    return 0 if total_items.zero?
    (picked_items.to_f / total_items * 100).round(2)
  end

  def is_overdue?
    started_at.present? && started_at < 4.hours.ago && !completed?
  end

  def estimated_completion_time
    return nil unless started_at && !completed?

    remaining_items = total_items - picked_items
    estimated_minutes = remaining_items * 2 # 2 minutes per item average

    started_at + estimated_minutes.minutes
  end

  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  def can_be_assigned_to?(admin)
    pending?
  end

  def assign_to!(admin)
    return false unless can_be_assigned_to?(admin)

    update(admin: admin, status: "assigned")
  end

  def start!
    return false unless assigned?

    begin
      update!(status: "in_progress")
      true
    rescue => e
      Rails.logger.error "Failed to start pick list: #{e.message}"
      false
    end
  end

  def complete!
    return false unless in_progress?

    # Simple completion without strict validation for now
    begin
      update!(status: "completed")
      
      # Update order status if possible
      begin
        order.update!(fulfillment_status: "picked")
      rescue => order_error
        Rails.logger.warn "Could not update order status: #{order_error.message}"
      end
      
      true
    rescue => e
      Rails.logger.error "Failed to complete pick list: #{e.message}"
      false
    end
  end

  def cancel!(reason = nil)
    return false if completed?

    begin
      update!(status: "cancelled")
      true
    rescue => e
      Rails.logger.error "Failed to cancel pick list: #{e.message}"
      false
    end
  end

  def all_items_picked?
    picked_items >= total_items
  end

  def remaining_items
    total_items - picked_items
  end

  def next_item_to_pick
    pick_list_items.pending.order(:sequence).first
  end

  def optimized_route
    # Simple optimization by zone and aisle
    pick_list_items.pending
                   .joins(location: :zone)
                   .order("zones.name, locations.aisle, locations.bay, locations.level")
  end

  # Status helper methods
  STATUSES.each do |status_name|
    define_method "#{status_name}?" do
      status == status_name
    end
  end

  # Priority helper methods
  def urgent?
    priority == "urgent"
  end

  def high_priority?
    priority == "high"
  end

  # Class methods
  def self.generate_number
    date_prefix = Date.current.strftime("%Y%m%d")
    last_number = where("pick_list_number LIKE ?", "PL#{date_prefix}%")
                    .order(:pick_list_number)
                    .last
                    &.pick_list_number

    if last_number
      sequence = last_number.last(4).to_i + 1
    else
      sequence = 1
    end

    "PL#{date_prefix}#{sequence.to_s.rjust(4, '0')}"
  end

  def self.create_for_order(order, admin: nil)
    return nil if order.pick_lists.active.exists?

    admin ||= Admin.first # Default admin if none specified

    begin
      PickListService.generate_pick_list(
        order: order,
        admin: admin,
        warehouse: order.warehouse
      )
    rescue PickListService::InsufficientStockError => e
      Rails.logger.error "Failed to create pick list: #{e.message}"
      nil
    end
  end

  def self.daily_metrics(date = Date.current)
    daily_lists = where(created_at: date.beginning_of_day..date.end_of_day)

    {
      total_created: daily_lists.count,
      completed: daily_lists.completed.count,
      in_progress: daily_lists.in_progress.count,
      average_completion_time: daily_lists.completed
                                         .where.not(started_at: nil, completed_at: nil)
                                         .average("EXTRACT(EPOCH FROM (completed_at - started_at))")
                                         &.seconds,
      total_items_picked: daily_lists.sum(:picked_items)
    }
  end

  private

  def generate_pick_list_number
    self.pick_list_number ||= self.class.generate_number
  end

  def update_progress_counters
    self.total_items = pick_list_items.sum(:quantity_requested)
    self.picked_items = pick_list_items.sum(:quantity_picked)
  end

  def create_pick_list_items
    return unless order.order_products.any?

    sequence = 1

    order.order_products.includes(:product).each do |order_product|
      # Find best location for this product with sufficient stock
      best_locations = Location.joins(:stocks)
                              .joins(zone: :warehouse)
                              .where(warehouses: { id: warehouse.id })
                              .where(stocks: { product: order_product.product })
                              .where("stocks.amount > 0")
                              .where("stocks.amount - stocks.reserved_quantity >= ?", order_product.quantity)
                              .order(Arel.sql("zones.zone_type = 'picking' DESC, stocks.expiry_date ASC NULLS LAST"))
                              .limit(1)

      location = best_locations.first
      next unless location # Skip if no suitable location found

      pick_list_items.create!(
        product: order_product.product,
        location: location,
        quantity_requested: order_product.quantity,
        size: order_product.size,
        sequence: sequence,
        status: "pending"
      )

      sequence += 1
    end

    reload # Refresh to get updated counters
    update_progress_counters
    save!
  end

  def create_picking_tasks
    pick_list_items.each do |item|
      next unless item.quantity_picked > 0

      Task.create_pick(
        admin: admin,
        warehouse: warehouse,
        product: item.product,
        quantity: item.quantity_picked,
        from_location: item.location,
        instructions: "Pick for order #{order.id} - Pick List #{pick_list_number}"
      )
    end
  end

  def update_order_fulfillment_status
    if status_changed? && completed?
      order.update!(fulfillment_status: "picked")
    end
  end
end
