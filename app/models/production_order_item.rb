class ProductionOrderItem < ApplicationRecord
  belongs_to :production_order

  # Validations
  validates :folio_consecutivo, presence: true, uniqueness: true
  validates :peso_bruto, numericality: { greater_than: 0 }, allow_nil: true
  validates :peso_neto, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :metros_lineales, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :peso_core_gramos, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :micras, numericality: { greater_than: 0 }, allow_nil: true
  validates :ancho_mm, numericality: { greater_than: 0 }, allow_nil: true
  validates :altura_cm, numericality: { greater_than: 0 }, allow_nil: true

  # Status enum
  ITEM_STATUSES = %w[pending in_production completed cancelled].freeze
  validates :status, inclusion: { in: ITEM_STATUSES }, allow_blank: true

  # Callbacks
  before_validation :auto_assign_peso_core
  before_validation :calculate_peso_neto
  before_validation :calculate_metros_lineales
  before_save :auto_populate_client_fields

  # Métodos de cálculo según las especificaciones
  def calculate_peso_neto
    return if peso_bruto.blank?

    # Asegurar que peso_core_gramos no sea nil
    core_weight = peso_core_gramos || 0

    # Peso neto = Peso bruto (kg) - (Peso core en gramos / 1000)
    calculated_peso_neto = peso_bruto - (core_weight / 1000.0)
    self.peso_neto = [0, calculated_peso_neto].max
  end

  def calculate_metros_lineales
    return if peso_neto.blank? || micras.blank? || ancho_mm.blank?
    return if micras <= 0 || ancho_mm <= 0  # Evitar división por cero

    # Metros lineales = ((Peso neto * 1,000,000) / micras / ancho mm / 0.92)
    calculated_metros = ((peso_neto * 1_000_000) / micras / ancho_mm / 0.92)
    self.metros_lineales = [0, calculated_metros].max.round(4)
  end

  # Generar folio consecutivo basado en el lote de la orden padre
  def self.generate_folio_consecutivo(production_order)
    lote_base = production_order.lote_referencia
    return nil if lote_base.blank?

    # Buscar el último consecutivo para este lote
    last_folio = production_order.production_order_items
                                .where("folio_consecutivo LIKE ?", "#{lote_base}-%")
                                .order(:folio_consecutivo)
                                .last

    if last_folio
      # Extraer el número consecutivo y incrementar
      consecutive_number = last_folio.folio_consecutivo.split("-").last.to_i + 1
    else
      consecutive_number = 1
    end

    "#{lote_base}-#{consecutive_number}"
  end

  # Core weight lookup table (altura_cm -> peso_core_gramos)
  CORE_WEIGHT_TABLE = {
    3 => 72, 4 => 96, 5 => 120, 6 => 144, 7 => 168, 8 => 192, 9 => 216, 10 => 240,
    11 => 264, 12 => 288, 13 => 312, 14 => 336, 15 => 360, 16 => 384, 17 => 408, 18 => 432,
    19 => 456, 20 => 480, 21 => 504, 22 => 528, 23 => 552, 24 => 576, 25 => 600, 26 => 624,
    27 => 648, 28 => 672, 29 => 696, 30 => 720, 31 => 744, 32 => 768, 33 => 792, 34 => 816,
    35 => 840, 36 => 864, 37 => 888, 38 => 912, 39 => 936, 40 => 960, 41 => 984, 42 => 1008,
    43 => 1032, 44 => 1056, 45 => 1080, 46 => 1104, 47 => 1128, 48 => 1152, 49 => 1176, 50 => 1200
  }.freeze

  # Obtener peso del core basado en altura
  def get_peso_core_from_altura
    return nil if altura_cm.blank?
    CORE_WEIGHT_TABLE[altura_cm]
  end

  # Auto-asignar peso del core si no está presente
  def auto_assign_peso_core
    return if peso_core_gramos.present? || altura_cm.blank?
    self.peso_core_gramos = get_peso_core_from_altura
  end

  # Helper methods
  def peso_core_kg
    return 0 if peso_core_gramos.blank?
    peso_core_gramos / 1000.0
  end

  def display_name
    folio_consecutivo || "Item #{id}"
  end

  # Extract client name from production order notes
  def extract_cliente_from_notes
    return self.cliente if self.cliente.present?

    # Try to extract client from production order notes
    notes = production_order.notes
    return nil if notes.blank?

    # Look for patterns like "Cliente: NOMBRE" or just return the notes
    if notes.match(/cliente:\s*(.+)/i)
      $1.strip
    else
      notes.strip
    end
  end

  # Auto-populate client fields from production order
  def auto_populate_client_fields
    return if self.cliente.present?

    self.cliente = extract_cliente_from_notes
    self.numero_de_orden = production_order.no_opro || production_order.order_number
    self.nombre_cliente_numero_pedido = "#{self.cliente}-#{self.numero_de_orden}" if self.cliente.present?
  end

  # Get complete label data for printing
  def label_data
    {
      name: folio_consecutivo&.split("-")&.last,
      lote: production_order.lote_referencia,
      clave_producto: production_order.clave_producto,
      peso_bruto: peso_bruto,
      peso_neto: peso_neto,
      metros_lineales: metros_lineales,
      cliente: extract_cliente_from_notes,
      numero_de_orden: production_order.no_opro || production_order.order_number,
      nombre_cliente_numero_pedido: nombre_cliente_numero_pedido || "#{extract_cliente_from_notes}-#{production_order.no_opro || production_order.order_number}"
    }
  end
end
