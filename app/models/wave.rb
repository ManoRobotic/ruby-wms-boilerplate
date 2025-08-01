class Wave < ApplicationRecord
  belongs_to :warehouse
  belongs_to :admin, optional: true
  has_many :orders, dependent: :nullify
  has_many :pick_lists, dependent: :nullify
  has_many :order_products, through: :orders

  # Enums for status
  STATUSES = %w[planning ready_to_release released in_progress completed cancelled].freeze
  WAVE_TYPES = %w[standard express batch zone_based priority hot].freeze
  STRATEGIES = %w[zone_based priority_based fifo lifo shortest_path product_family].freeze

  validates :name, presence: true, uniqueness: { scope: :warehouse_id }
  validates :status, inclusion: { in: STATUSES }
  validates :wave_type, inclusion: { in: WAVE_TYPES }
  validates :strategy, inclusion: { in: STRATEGIES }
  validates :priority, numericality: { in: 1..10 }
  validates :total_orders, :total_items, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :active, -> { where(status: %w[planning ready_to_release released in_progress]) }
  scope :completed, -> { where(status: 'completed') }
  scope :by_warehouse, ->(warehouse_id) { where(warehouse_id: warehouse_id) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_priority, -> { order(:priority, :created_at) }
  scope :scheduled_for_today, -> { where(planned_start_time: Date.current.beginning_of_day..Date.current.end_of_day) }

  # Callbacks
  before_validation :set_default_name, if: -> { name.blank? }
  before_save :calculate_totals
  after_update :update_pick_lists_status, if: :saved_change_to_status?

  # Status methods
  def planning?
    status == 'planning'
  end

  def ready_to_release?
    status == 'ready_to_release'
  end

  def released?
    status == 'released'
  end

  def in_progress?
    status == 'in_progress'
  end

  def completed?
    status == 'completed'
  end

  def cancelled?
    status == 'cancelled'
  end

  def active?
    %w[planning ready_to_release released in_progress].include?(status)
  end

  # Business methods
  def can_be_released?
    planning? && orders.any? && planned_start_time.present?
  end

  def can_be_started?
    ready_to_release? || released?
  end

  def can_be_completed?
    in_progress? && all_pick_lists_completed?
  end

  def duration_minutes
    return nil unless actual_start_time && actual_end_time
    ((actual_end_time - actual_start_time) / 1.minute).round
  end

  def estimated_duration_minutes
    return nil unless orders.any?
    # Estimación básica: 2 minutos por ítem + 5 minutos por orden
    (total_items * 2) + (total_orders * 5)
  end

  def completion_percentage
    return 0 unless pick_lists.any?
    completed_pick_lists = pick_lists.where(status: 'completed').count
    (completed_pick_lists.to_f / pick_lists.count * 100).round(1)
  end

  def efficiency_score
    return nil unless completed? && duration_minutes && estimated_duration_minutes
    return 100 if duration_minutes <= estimated_duration_minutes
    (estimated_duration_minutes.to_f / duration_minutes * 100).round(1)
  end

  # Actions
  def release!
    return false unless can_be_released?
    
    transaction do
      update!(status: 'ready_to_release')
      generate_pick_lists
      update!(status: 'released') if pick_lists.any?
    end
  end

  def start!
    return false unless can_be_started?
    update!(status: 'in_progress', actual_start_time: Time.current)
  end

  def complete!
    return false unless can_be_completed?
    update!(status: 'completed', actual_end_time: Time.current)
  end

  def cancel!
    return false if completed?
    
    transaction do
      pick_lists.update_all(status: 'cancelled')
      orders.update_all(wave_id: nil)
      update!(status: 'cancelled')
    end
  end

  private

  def set_default_name
    self.name = "WAVE-#{warehouse.code}-#{Date.current.strftime('%Y%m%d')}-#{sprintf('%03d', warehouse.waves.where(created_at: Date.current.beginning_of_day..Date.current.end_of_day).count + 1)}"
  end

  def calculate_totals
    self.total_orders = orders.count
    self.total_items = order_products.sum(:quantity)
  end

  def all_pick_lists_completed?
    pick_lists.any? && pick_lists.where.not(status: 'completed').empty?
  end

  def generate_pick_lists
    WaveProcessingJob.perform_later(self)
  end

  def update_pick_lists_status
    case status
    when 'cancelled'
      pick_lists.update_all(status: 'cancelled')
    when 'in_progress'
      pick_lists.where(status: 'pending').update_all(status: 'in_progress')
    end
  end
end