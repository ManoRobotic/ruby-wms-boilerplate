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

  # New enum for print status
  enum :print_status, { pending_printing: 0, printed: 1 }
  validates :print_status, presence: true

  # Callbacks
  before_validation :auto_assign_peso_core
  before_validation :calculate_peso_neto
  before_validation :calculate_metros_lineales
  before_save :auto_populate_client_fields
  after_commit :update_production_order_quantity, on: [:create, :destroy]

  # Get complete label data for printing
  def label_data
    {
      folio_consecutivo: folio_consecutivo,
      name: folio_consecutivo&.split("-")&.last,
      lote: production_order.lote_referencia,
      clave_producto: production_order.product&.sku,
      peso_bruto: peso_bruto || 0,
      peso_neto: peso_neto || 0,
      metros_lineales: metros_lineales || 0,
      cliente: extract_cliente_from_notes,
      numero_de_orden: production_order.no_opro || production_order.order_number,
      nombre_cliente_numero_pedido: nombre_cliente_numero_pedido || "#{extract_cliente_from_notes}-#{production_order.no_opro || production_order.order_number}",
      fecha_creacion: production_order.created_at.strftime("%d/%m/%Y"),
      ancho_mm: ancho_mm || 0,
      micras: micras || 0
    }
  end

  private

  def update_production_order_quantity
    # Only try to update if the production order still exists and is not being destroyed
    return if production_order.nil? || production_order.destroyed? || production_order.frozen?
    
    production_order.recalculate_quantity_produced_and_broadcast!
  end

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

    # Buscar TODOS los consecutivos existentes para este lote (no solo de esta orden)
    existing_folios = ProductionOrderItem.where("folio_consecutivo LIKE ?", "#{lote_base}-%")
                                        .pluck(:folio_consecutivo)
    
    # Extraer los números consecutivos existentes
    existing_numbers = existing_folios.map do |folio|
      folio.split("-").last.to_i
    end.compact.sort
    
    # Encontrar el siguiente número disponible
    consecutive_number = 1
    existing_numbers.each do |num|
      if consecutive_number == num
        consecutive_number += 1
      else
        break
      end
    end

    "#{lote_base}-#{consecutive_number}"
  end

  # Core weight lookup table (altura_cm -> peso_core_gramos)
  CORE_WEIGHT_TABLE = {
    0 => 0, 70 => 200, 80 => 200, 90 => 200, 100 => 200, 110 => 200, 120 => 200, 
    124 => 200, 130 => 200, 140 => 200, 142 => 200, 143 => 200, 150 => 200, 
    160 => 200, 170 => 200, 180 => 200, 190 => 400, 200 => 400, 210 => 400, 
    220 => 400, 230 => 400, 240 => 500, 250 => 500, 260 => 500, 270 => 500, 
    280 => 500, 290 => 600, 300 => 600, 310 => 600, 320 => 600, 330 => 600, 
    340 => 700, 350 => 700, 360 => 700, 370 => 700, 380 => 700, 390 => 700, 
    400 => 800, 410 => 800, 420 => 800, 430 => 800, 440 => 900, 450 => 900, 
    460 => 900, 470 => 900, 480 => 900, 490 => 1000, 500 => 1000, 510 => 1000, 
    520 => 1000, 530 => 1000, 540 => 1100, 550 => 1100, 560 => 1100, 570 => 1100, 
    580 => 1100, 590 => 1200, 600 => 1200, 610 => 1200, 620 => 1200, 630 => 1200, 
    640 => 1300, 650 => 1300, 660 => 1300, 670 => 1300, 680 => 1300, 690 => 1400, 
    700 => 1400, 710 => 1400, 720 => 1400, 730 => 1400, 740 => 1500, 750 => 1500, 
    760 => 1500, 770 => 1500, 780 => 1500, 790 => 1600, 800 => 1600, 810 => 1600, 
    820 => 1600, 830 => 1600, 840 => 1700, 850 => 1700, 860 => 1700, 870 => 17.00, 
    880 => 1700, 890 => 1800, 900 => 1800, 910 => 1800, 920 => 1800, 930 => 1800, 
    940 => 1900, 950 => 1900, 960 => 1900, 970 => 1900, 980 => 1900, 990 => 2000, 
    1000 => 2000, 1020 => 2000, 1040 => 1200, 1050 => 1200, 1060 => 1200, 
    1100 => 2200, 1120 => 2200, 1140 => 2300, 1160 => 2300, 1180 => 2400, 
    1200 => 2400, 1220 => 2400, 1240 => 2500, 1250 => 2500, 1260 => 2600, 
    1300 => 2600, 1320 => 2600, 1340 => 2700, 1360 => 2700, 1400 => 2800
  }.freeze

  # Obtener peso del core basado en altura
  def get_peso_core_from_altura
    return nil if altura_cm.blank?
    
    # Buscar el peso core más cercano
    keys = CORE_WEIGHT_TABLE.keys.sort
    
    # Si la altura es menor que el primer valor, usar el primer peso
    return CORE_WEIGHT_TABLE[keys.first] if altura_cm <= keys.first
    
    # Si la altura es mayor que el último valor, usar el último peso
    return CORE_WEIGHT_TABLE[keys.last] if altura_cm >= keys.last
    
    # Encontrar el valor más cercano
    keys.each_with_index do |key, index|
      if altura_cm >= key && altura_cm < keys[index + 1]
        return CORE_WEIGHT_TABLE[key]
      end
    end
    
    CORE_WEIGHT_TABLE[keys.last]
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
end
