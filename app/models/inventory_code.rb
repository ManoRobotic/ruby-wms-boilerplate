class InventoryCode < ApplicationRecord
  # Validations
  validates :no_ordp, presence: true
  validates :cve_copr, presence: true
  validates :cve_prod, presence: true
  validates :can_copr, numericality: { greater_than: 0 }, allow_nil: true
  validates :costo, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes for filtering
  scope :by_order_number, ->(number) { where("no_ordp ILIKE ?", "%#{number}%") if number.present? }
  scope :by_product_code, ->(code) { where("cve_prod ILIKE ?", "%#{code}%") if code.present? }
  scope :by_component_code, ->(code) { where("cve_copr ILIKE ?", "%#{code}%") if code.present? }
  scope :by_lote, ->(lote) { where("lote ILIKE ?", "%#{lote}%") if lote.present? }
  scope :by_date_range, ->(start_date, end_date) do
    if start_date.present? && end_date.present?
      where(fech_cto: start_date..end_date)
    elsif start_date.present?
      where("fech_cto >= ?", start_date)
    elsif end_date.present?
      where("fech_cto <= ?", end_date)
    end
  end

  # Helper methods
  def display_name
    "#{no_ordp} - #{cve_prod}"
  end

  def formatted_cost
    return "N/A" if costo.blank?
    "#{costo.round(2)}"
  end

  def formatted_quantity
    return "N/A" if can_copr.blank?
    "#{can_copr.round(3)} #{undres || 'KG'}"
  end

  def status_display
    case tip_copr
    when 1
      "Activo"
    when 0
      "Inactivo"
    else
      "Desconocido"
    end
  end
end