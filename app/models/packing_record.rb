class PackingRecord < ApplicationRecord
  belongs_to :production_order
  
  validates :lote, presence: true
  validates :cve_prod, presence: true
  validates :peso_bruto, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :peso_neto, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :metros_lineales, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :consecutivo, presence: true, numericality: { greater_than: 0 }
  validates :consecutivo, uniqueness: { scope: :production_order_id }
  
  scope :by_lote_padre, ->(lote_padre) { where(lote_padre: lote_padre) }
  scope :by_cve_prod, ->(cve_prod) { where(cve_prod: cve_prod) }
  scope :recent, -> { order(created_at: :desc) }
  
  def display_name
    "#{lote} - #{cve_prod}"
  end
  
  def peso_diferencia
    peso_bruto - peso_neto if peso_bruto && peso_neto
  end
  
  def micras
    return nil unless cve_prod
    
    # Extract micras from CVE_PROD format like "BOPPTRANS 35 / 420"
    match = cve_prod.match(/(\d+)\s*\/\s*\d+/)
    match[1].to_i if match
  end
  
  def ancho_mm
    return nil unless cve_prod
    
    # Extract width from CVE_PROD format like "BOPPTRANS 35 / 420"  
    match = cve_prod.match(/\d+\s*\/\s*(\d+)/)
    match[1].to_i if match
  end
  
  def barcode_data
    {
      id: id,
      lote: lote,
      cve_prod: cve_prod,
      peso_neto: peso_neto,
      metros_lineales: metros_lineales,
      consecutivo: consecutivo,
      production_order_id: production_order_id,
      created_at: created_at.iso8601
    }.to_json
  end
end