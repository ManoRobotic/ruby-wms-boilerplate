class InventoryTransaction < ApplicationRecord
  # Associations
  belongs_to :warehouse
  belongs_to :location, optional: true
  belongs_to :product
  belongs_to :admin
  belongs_to :reference, polymorphic: true, optional: true

  # Validations
  validates :transaction_type, presence: true
  validates :quantity, presence: true, numericality: { other_than: 0 }
  validates :unit_cost, numericality: { greater_than: 0 }, allow_nil: true
  validates :reason, length: { maximum: 1000 }
  validates :batch_number, length: { maximum: 50 }

  # Enums
  TRANSACTION_TYPES = %w[
    receipt
    putaway
    pick
    move
    adjustment_in
    adjustment_out
    cycle_count
    return_to_vendor
    return_from_customer
    transfer_in
    transfer_out
    damage
    shrinkage
    expiry
    sale
  ].freeze

  validates :transaction_type, inclusion: { in: TRANSACTION_TYPES }

  # Scopes
  scope :by_type, ->(type) { where(transaction_type: type) }
  scope :by_warehouse, ->(warehouse) { where(warehouse: warehouse) }
  scope :by_location, ->(location) { where(location: location) }
  scope :by_product, ->(product) { where(product: product) }
  scope :by_admin, ->(admin) { where(admin: admin) }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :today, -> { where(created_at: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :this_week, -> { where(created_at: 1.week.ago..Time.current) }
  scope :this_month, -> { where(created_at: 1.month.ago..Time.current) }
  scope :inbound, -> { where(transaction_type: %w[receipt putaway adjustment_in return_from_customer transfer_in]) }
  scope :outbound, -> { where(transaction_type: %w[pick sale adjustment_out return_to_vendor transfer_out damage shrinkage expiry]) }
  scope :adjustments, -> { where(transaction_type: %w[adjustment_in adjustment_out cycle_count]) }
  scope :movements, -> { where(transaction_type: %w[move putaway pick]) }
  scope :with_cost, -> { where.not(unit_cost: nil) }
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  after_create :update_stock_levels
  after_create :log_inventory_change

  # Instance methods
  def display_name
    "#{transaction_type.humanize} - #{product.name}"
  end

  def total_value
    return 0 unless unit_cost
    (quantity.abs * unit_cost).round(2)
  end

  def is_inbound?
    %w[receipt putaway adjustment_in return_from_customer transfer_in].include?(transaction_type)
  end

  def is_outbound?
    %w[pick sale adjustment_out return_to_vendor transfer_out damage shrinkage expiry].include?(transaction_type)
  end

  def is_adjustment?
    %w[adjustment_in adjustment_out cycle_count].include?(transaction_type)
  end

  def is_movement?
    %w[move putaway pick].include?(transaction_type)
  end

  def affects_stock_levels?
    !%w[move].include?(transaction_type)
  end

  def reference_display
    return "N/A" unless reference

    case reference
    when Order then "Order ##{reference.id}"
    when Task then "Task ##{reference.id}"
    when Receipt then "Receipt ##{reference.reference_number}"
    when PickList then "Pick List ##{reference.pick_list_number}"
    else "#{reference.class.name} ##{reference.id}"
    end
  end

  def location_display
    location&.coordinate_code || "No Location"
  end

  def batch_info
    return "No Batch" unless batch_number

    info = "Batch: #{batch_number}"
    info += ", Expires: #{expiry_date.strftime('%Y-%m-%d')}" if expiry_date
    info
  end

  # Class methods
  def self.create_receipt(product:, quantity:, location:, admin:, **options)
    create!(
      warehouse: location.warehouse,
      location: location,
      product: product,
      transaction_type: "receipt",
      quantity: quantity.abs,
      unit_cost: options[:unit_cost],
      admin: admin,
      reference: options[:reference],
      reason: options[:reason] || "Goods received",
      batch_number: options[:batch_number],
      expiry_date: options[:expiry_date],
      size: options[:size]
    )
  end

  def self.create_pick(product:, quantity:, location:, admin:, **options)
    create!(
      warehouse: location.warehouse,
      location: location,
      product: product,
      transaction_type: "pick",
      quantity: -quantity.abs, # Negative for outbound
      admin: admin,
      reference: options[:reference],
      reason: options[:reason] || "Item picked for order",
      batch_number: options[:batch_number],
      size: options[:size]
    )
  end

  def self.create_adjustment(product:, quantity:, location:, admin:, reason:, **options)
    transaction_type = quantity > 0 ? "adjustment_in" : "adjustment_out"

    create!(
      warehouse: location.warehouse,
      location: location,
      product: product,
      transaction_type: transaction_type,
      quantity: quantity,
      admin: admin,
      reason: reason,
      batch_number: options[:batch_number],
      expiry_date: options[:expiry_date],
      size: options[:size]
    )
  end

  def self.create_move(product:, from_location:, to_location:, quantity:, admin:, **options)
    # Create outbound transaction from source
    create!(
      warehouse: from_location.warehouse,
      location: from_location,
      product: product,
      transaction_type: "move",
      quantity: -quantity.abs,
      admin: admin,
      reference: options[:reference],
      reason: options[:reason] || "Moved to #{to_location.coordinate_code}",
      batch_number: options[:batch_number],
      size: options[:size]
    )

    # Create inbound transaction to destination
    create!(
      warehouse: to_location.warehouse,
      location: to_location,
      product: product,
      transaction_type: "move",
      quantity: quantity.abs,
      admin: admin,
      reference: options[:reference],
      reason: options[:reason] || "Moved from #{from_location.coordinate_code}",
      batch_number: options[:batch_number],
      size: options[:size]
    )
  end

  def self.daily_summary(date = Date.current)
    daily_transactions = where(created_at: date.beginning_of_day..date.end_of_day)

    {
      total_transactions: daily_transactions.count,
      inbound_transactions: daily_transactions.inbound.count,
      outbound_transactions: daily_transactions.outbound.count,
      adjustment_transactions: daily_transactions.adjustments.count,
      total_inbound_quantity: daily_transactions.inbound.sum(:quantity),
      total_outbound_quantity: daily_transactions.outbound.sum("ABS(quantity)"),
      total_value: daily_transactions.with_cost.sum("ABS(quantity) * unit_cost"),
      unique_products: daily_transactions.distinct.count(:product_id),
      unique_locations: daily_transactions.where.not(location: nil).distinct.count(:location_id)
    }
  end

  def self.inventory_movement_report(start_date, end_date)
    transactions = where(created_at: start_date..end_date)

    {
      period: "#{start_date.strftime('%Y-%m-%d')} to #{end_date.strftime('%Y-%m-%d')}",
      total_transactions: transactions.count,
      inbound_value: transactions.inbound.with_cost.sum("quantity * unit_cost"),
      outbound_value: transactions.outbound.with_cost.sum("ABS(quantity) * unit_cost"),
      net_quantity_change: transactions.sum(:quantity),
      top_products: transactions.joins(:product)
                              .group("products.name")
                              .sum("ABS(quantity)")
                              .sort_by { |_, qty| -qty }
                              .first(10),
      transaction_types_breakdown: transactions.group(:transaction_type).count
    }
  end

  def self.product_movement_history(product, limit = 50)
    where(product: product)
      .includes(:warehouse, :location, :admin)
      .order(created_at: :desc)
      .limit(limit)
  end

  def self.location_activity(location, days = 30)
    where(location: location)
      .where(created_at: days.days.ago..Time.current)
      .includes(:product, :admin)
      .order(created_at: :desc)
  end

  private

  def update_stock_levels
    return unless affects_stock_levels? && location

    begin
      stock = Stock.find_or_initialize_by(
        product: product,
        location: location,
        size: size || "standard",
        batch_number: batch_number
      )

      if stock.persisted?
        new_amount = stock.amount + quantity

        if new_amount <= 0
          stock.destroy
        else
          stock.update!(
            amount: new_amount,
            unit_cost: unit_cost || stock.unit_cost,
            expiry_date: expiry_date || stock.expiry_date,
            received_date: is_inbound? ? Date.current : stock.received_date
          )
        end
      elsif quantity > 0
        # Only create new stock record for positive quantities
        stock.assign_attributes(
          amount: quantity,
          unit_cost: unit_cost,
          expiry_date: expiry_date,
          received_date: Date.current
        )
        stock.save!
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to update stock levels: #{e.message}"
      # Don't re-raise to avoid breaking the transaction creation
    end
  end

  def log_inventory_change
    Rails.logger.info "Inventory Transaction: #{transaction_type} - #{product.name} - Qty: #{quantity} - Location: #{location&.coordinate_code} - Admin: #{admin.email}"
  end
end
