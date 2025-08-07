class ProductionOrder < ApplicationRecord
  belongs_to :warehouse
  belongs_to :product
  belongs_to :admin, optional: true
  
  # Validations
  validates :order_number, presence: true, uniqueness: true
  validates :status, presence: true
  validates :priority, presence: true
  validates :quantity_requested, presence: true, numericality: { greater_than: 0 }
  validates :quantity_produced, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # Enums
  STATUSES = %w[pending scheduled in_progress paused completed cancelled].freeze
  PRIORITIES = %w[low medium high urgent].freeze
  
  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }
  
  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :by_warehouse, ->(warehouse) { where(warehouse: warehouse) }
  scope :pending, -> { where(status: 'pending') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :completed, -> { where(status: 'completed') }
  scope :active, -> { where(status: %w[pending scheduled in_progress paused]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  
  # Callbacks
  before_validation :generate_order_number, on: :create
  before_save :set_actual_completion
  
  # Instance methods
  def display_name
    "#{order_number} - #{product.name}"
  end
  
  def progress_percentage
    return 0 if quantity_requested == 0 || quantity_produced.nil?
    [(quantity_produced.to_f / quantity_requested * 100).round(2), 100].min
  end
  
  def is_overdue?
    estimated_completion.present? && estimated_completion < Time.current && !completed?
  end
  
  def remaining_quantity
    quantity_requested - (quantity_produced || 0)
  end
  
  def can_be_started?
    pending? || status == 'scheduled'
  end
  
  def can_be_paused?
    status == 'in_progress'
  end
  
  def can_be_completed?
    status == 'in_progress' && quantity_produced.present? && quantity_produced > 0
  end
  
  def start!
    return false unless can_be_started?
    update(status: 'in_progress', start_date: Time.current)
  end
  
  def pause!
    return false unless can_be_paused?
    update(status: 'paused')
  end
  
  def complete!
    return false unless can_be_completed?
    update(
      status: 'completed',
      actual_completion: Time.current,
      quantity_produced: quantity_produced || quantity_requested
    )
  end
  
  def cancel!(reason = nil)
    return false if completed?
    notes_with_reason = reason ? "#{notes}\nCancelado: #{reason}".strip : notes
    update(status: 'cancelled', notes: notes_with_reason)
  end
  
  # Status helper methods
  STATUSES.each do |status_name|
    define_method "#{status_name}?" do
      status == status_name
    end
  end
  
  # Priority helper methods  
  def urgent?
    priority == 'urgent'
  end
  
  def high_priority?
    priority == 'high'
  end
  
  private
  
  def generate_order_number
    return if order_number.present?
    
    prefix = "PO#{Date.current.strftime('%Y%m')}"
    last_number = ProductionOrder.where("order_number LIKE ?", "#{prefix}%")
                                  .maximum(:order_number)
                                  &.gsub(prefix, '')
                                  &.to_i || 0
    
    self.order_number = "#{prefix}#{(last_number + 1).to_s.rjust(4, '0')}"
  end
  
  def set_actual_completion
    if status_changed? && completed?
      self.actual_completion = Time.current
    elsif status_changed? && !completed?
      self.actual_completion = nil
    end
  end
end
