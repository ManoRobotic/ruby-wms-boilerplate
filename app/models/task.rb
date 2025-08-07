class Task < ApplicationRecord
  # Associations
  # Note: admin_id can reference either Admin or User, so no belongs_to association
  
  # Custom method to get the assigned person (Admin or User)
  def assigned_to
    Admin.find_by(id: admin_id) || User.find_by(id: admin_id)
  end
  
  belongs_to :warehouse
  belongs_to :location, optional: true
  belongs_to :product, optional: true
  belongs_to :from_location, class_name: "Location", optional: true
  belongs_to :to_location, class_name: "Location", optional: true
  
  # Inventory transactions created by completing this task
  has_many :inventory_transactions, -> { where(reference_type: 'Task') },
           foreign_key: :reference_id

  # Validations
  validates :task_type, presence: true
  validates :priority, presence: true
  validates :status, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :instructions, length: { maximum: 1000 }

  # Enums
  TASK_TYPES = %w[
    putaway
    picking
    replenishment
    cycle_count
    move
    adjustment
    receiving
    shipping
    consolidation
    cleanup
  ].freeze

  PRIORITIES = %w[low medium high urgent].freeze
  STATUSES = %w[pending assigned in_progress completed cancelled].freeze

  validates :task_type, inclusion: { in: TASK_TYPES }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :status, inclusion: { in: STATUSES }

  # Scopes
  scope :by_type, ->(type) { where(task_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :by_warehouse, ->(warehouse) { where(warehouse: warehouse) }
  scope :by_admin, ->(admin) { where(admin: admin) }
  scope :pending, -> { where(status: "pending") }
  scope :assigned, -> { where(status: "assigned") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :completed, -> { where(status: "completed") }
  scope :active, -> { where(status: [ "pending", "assigned", "in_progress" ]) }
  scope :overdue, -> { where("assigned_at < ? AND status != ?", 1.day.ago, "completed") }
  scope :high_priority, -> { where(priority: [ "high", "urgent" ]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_priority_order, -> { order(Arel.sql("CASE priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END")) }

  # Callbacks
  before_save :set_assigned_at
  before_save :set_completed_at
  after_update :create_inventory_transaction, if: :completed_and_affects_inventory?

  # Instance methods
  def display_name
    "#{task_type.humanize} - #{product&.name || 'N/A'}"
  end

  def estimated_duration
    case task_type
    when "putaway" then 15.minutes
    when "picking" then 10.minutes
    when "replenishment" then 20.minutes
    when "cycle_count" then 30.minutes
    when "move" then 15.minutes
    else 15.minutes
    end
  end

  def is_overdue?
    assigned_at.present? && assigned_at < 1.day.ago && !completed?
  end

  def duration
    return nil unless assigned_at && completed_at
    completed_at - assigned_at
  end

  def can_be_assigned_to?(admin)
    pending? && warehouse.present?
  end

  def assign_to!(admin)
    return false unless can_be_assigned_to?(admin)

    update(admin_id: admin.id, status: "assigned", assigned_at: Time.current)
  end

  def assign_to_user!(user)
    Rails.logger.info "=== ASSIGN_TO_USER! DEBUG ==="
    Rails.logger.info "Task status: #{status}"
    Rails.logger.info "Task pending?: #{pending?}"
    Rails.logger.info "Warehouse present?: #{warehouse.present?}"
    Rails.logger.info "Warehouse: #{warehouse&.name}"
    
    unless pending? && warehouse.present?
      Rails.logger.error "Pre-condition failed: pending=#{pending?}, warehouse_present=#{warehouse.present?}"
      return false
    end

    begin
      Rails.logger.info "Attempting to update task with admin_id: #{user.id}"
      result = update!(admin_id: user.id, status: "assigned", assigned_at: Time.current)
      Rails.logger.info "Update result: #{result}"
      Rails.logger.info "Task after update - admin_id: #{admin_id}, status: #{status}"
      true
    rescue => e
      Rails.logger.error "Exception during update: #{e.class} - #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(3)}"
      false
    end
  end

  def start!
    return false unless assigned? && assigned_at.present?

    update(status: "in_progress")
  end

  def complete!(notes = nil)
    return false unless in_progress?

    update(
      status: "completed",
      completed_at: Time.current,
      instructions: [ instructions, notes ].compact.join("\n")
    )
  end

  def cancel!(reason = nil)
    return false if completed?

    update(
      status: "cancelled",
      instructions: [ instructions, "Cancelled: #{reason}" ].compact.join("\n")
    )
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

  def medium_priority?
    priority == "medium"
  end

  def low_priority?
    priority == "low"
  end

  # Task type helper methods
  def putaway_task?
    task_type == "putaway"
  end

  def picking_task?
    task_type == "picking"
  end

  def move_task?
    task_type == "move"
  end

  def cycle_count_task?
    task_type == "cycle_count"
  end

  def requires_product?
    %w[putaway picking replenishment move adjustment].include?(task_type)
  end

  def requires_locations?
    %w[putaway move].include?(task_type)
  end

  # Class methods
  def self.create_putaway(admin:, warehouse:, product:, quantity:, to_location:, instructions: nil)
    create!(
      admin: admin,
      warehouse: warehouse,
      task_type: "putaway",
      product: product,
      quantity: quantity,
      to_location: to_location,
      instructions: instructions || "Put away #{quantity} units of #{product.name} to #{to_location.coordinate_code}",
      priority: "medium",
      status: "pending"
    )
  end

  def self.create_pick(admin:, warehouse:, product:, quantity:, from_location:, instructions: nil)
    create!(
      admin: admin,
      warehouse: warehouse,
      task_type: "picking",
      product: product,
      quantity: quantity,
      from_location: from_location,
      location: from_location,
      instructions: instructions || "Pick #{quantity} units of #{product.name} from #{from_location.coordinate_code}",
      priority: "high",
      status: "pending"
    )
  end

  def self.create_move(admin:, warehouse:, product:, quantity:, from_location:, to_location:, instructions: nil)
    create!(
      admin: admin,
      warehouse: warehouse,
      task_type: "move",
      product: product,
      quantity: quantity,
      from_location: from_location,
      to_location: to_location,
      instructions: instructions || "Move #{quantity} units of #{product.name} from #{from_location.coordinate_code} to #{to_location.coordinate_code}",
      priority: "medium",
      status: "pending"
    )
  end

  def self.pending_count_by_type
    pending.group(:task_type).count
  end

  def self.average_completion_time
    completed.where.not(assigned_at: nil, completed_at: nil)
             .average("EXTRACT(EPOCH FROM (completed_at - assigned_at))")
             &.seconds
  end

  private

  def set_assigned_at
    if status_changed? && assigned?
      self.assigned_at ||= Time.current
    end
  end

  def set_completed_at
    if status_changed? && completed?
      self.completed_at = Time.current
    elsif status_changed? && !completed?
      self.completed_at = nil
    end
  end

  def completed_and_affects_inventory?
    status_changed? && completed? && %w[putaway picking move adjustment].include?(task_type)
  end

  def create_inventory_transaction
    return unless product && quantity

    transaction_type = case task_type
    when "putaway" then "putaway"
    when "picking" then "pick"
    when "move" then "move"
    when "adjustment" then "adjustment"
    else "task_completion"
    end

    InventoryTransaction.create!(
      warehouse: warehouse,
      location: to_location || location,
      product: product,
      transaction_type: transaction_type,
      quantity: quantity,
      admin: admin,
      reference_type: "Task",
      reference_id: id,
      reason: "Task completion: #{display_name}"
    )
  end
end
