class ProductionOrder < ApplicationRecord
  belongs_to :warehouse
  belongs_to :product
  belongs_to :admin, optional: true
  has_many :packing_records, dependent: :destroy
  has_many :production_order_items, dependent: :destroy

  # Validations
  validates :order_number, presence: true, uniqueness: true
  validates :status, presence: true
  validates :priority, presence: true
  validates :quantity_requested, presence: true, numericality: { greater_than: 0 }
  validates :quantity_produced, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :pieces_count, numericality: { greater_than: 0 }, allow_nil: true
  validates :package_count, numericality: { greater_than: 0 }, allow_nil: true
  validates :no_opro, uniqueness: true, allow_blank: true

  # Enums
  STATUSES = %w[pending scheduled in_progress paused completed cancelled].freeze
  PRIORITIES = %w[low medium high urgent].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :by_warehouse, ->(warehouse) { where(warehouse: warehouse) }
  scope :pending, -> { where(status: "pending") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :completed, -> { where(status: "completed") }
  scope :active, -> { where(status: %w[pending scheduled in_progress paused]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }

  # Callbacks
  before_validation :generate_order_number, on: :create
  before_save :set_actual_completion
  before_save :track_status_changes

  # Instance methods
  def display_name
    "#{order_number} - #{product.name}"
  end

  def progress_percentage
    return 0 if quantity_requested == 0 || quantity_produced.nil?
    [ (quantity_produced.to_f / quantity_requested * 100).round(2), 100 ].min
  end

  def is_overdue?
    estimated_completion.present? && estimated_completion < Time.current && !completed?
  end

  def remaining_quantity
    quantity_requested - (quantity_produced || 0)
  end

  def can_be_started?
    pending? || status == "scheduled"
  end

  def can_be_paused?
    status == "in_progress"
  end

  def can_be_completed?
    status == "in_progress" && quantity_produced.present? && quantity_produced > 0
  end

  def can_be_cancelled?
    !completed? && !cancelled?
  end

  def start!
    return false unless can_be_started?
    update(status: "in_progress", start_date: Time.current)
  end

  def pause!
    return false unless can_be_paused?
    update(status: "paused")
  end

  def complete!
    return false unless can_be_completed?
    update(
      status: "completed",
      actual_completion: Time.current,
      quantity_produced: quantity_produced || quantity_requested
    )
  end

  def cancel!(reason = nil)
    return false if completed?
    notes_with_reason = reason ? "#{notes}\nCancelado: #{reason}".strip : notes
    update(status: "cancelled", notes: notes_with_reason)
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

  # OPRO Google Sheet methods
  def generate_lote_from_fecha(fecha_opro)
    return nil if fecha_opro.blank?
    
    date = fecha_opro.is_a?(String) ? Date.parse(fecha_opro) : fecha_opro
    "FE-CR-#{date.strftime('%d%m%y')}"
  end

  def lote_referencia
    return self[:lote_referencia] if self[:lote_referencia].present?
    return generate_lote_from_fecha(fecha_completa) if fecha_completa.present?
    return generate_lote_from_fecha(created_at) if created_at.present?
    nil
  end

  def clave_producto
    # Buscar en packing_records primero, luego en product
    packing_records.first&.cve_prod || product&.name
  end

  def is_emitida?
    # Solo mostrar órdenes emitidas según las especificaciones
    status == "pending" || status == "scheduled" || status == "in_progress"
  end

  def barcode_data_for_bag_format
    {
      id: id,
      order_number: order_number,
      format: "bag",
      bolsa: bag_size,
      medida_bolsa: bag_measurement,
      numero_piezas: pieces_count,
      product: product.name,
      created_at: created_at.iso8601
    }.to_json
  end

  def barcode_data_for_box_format
    {
      id: id,
      order_number: order_number,
      format: "box",
      bolsa: bag_size,
      medida_bolsa: bag_measurement,
      numero_piezas: pieces_count,
      cantidad_paquetes: package_count,
      medida_paquetes: package_measurement,
      product: product.name,
      created_at: created_at.iso8601
    }.to_json
  end

  # Incremental sync methods
  def mark_for_sheet_update!
    update_column(:needs_update_to_sheet, true) unless needs_update_to_sheet?
  end

  def from_sheet_sync?
    # Determinar si el cambio viene de una sincronización del sheet
    @from_sheet_sync == true
  end

  def from_sheet_sync=(value)
    @from_sheet_sync = value
  end

  private

  def track_status_changes
    # Si el status cambió y no viene de sincronización del sheet, marcar para actualizar
    if status_changed? && !from_sheet_sync? && persisted?
      self.needs_update_to_sheet = true
      Rails.logger.debug "Orden #{no_opro} marcada para actualizar en sheet: status cambió a #{status}"
    end
  end

  def generate_order_number
    return if order_number.present?

    prefix = "PO#{Date.current.strftime('%Y%m')}"
    last_number = ProductionOrder.where("order_number LIKE ?", "#{prefix}%")
                                  .maximum(:order_number)
                                  &.gsub(prefix, "")
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
