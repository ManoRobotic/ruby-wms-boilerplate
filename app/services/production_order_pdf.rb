class ProductionOrderPdf
  include Prawn::View

  def initialize(production_order, production_order_items)
    @production_order = production_order
    @production_order_items = production_order_items
    @document = Prawn::Document.new
  end

  def render
    # Header
    text "Tabla de Consecutivos", size: 22, style: :bold, align: :center
    move_down 10

    text "<b>Orden:</b> #{@production_order.no_opro || @production_order.order_number || 'N/A'}", size: 12, inline_format: true
    text "<b>Producto:</b> #{@production_order.product&.name || 'N/A'}", size: 12, inline_format: true
    text "<b>Lote:</b> #{@production_order.lote_referencia || 'N/A'}", size: 12, inline_format: true
    text "<b>Fecha de Impresión:</b> #{Date.current.strftime('%d/%m/%Y')}", size: 12, inline_format: true

    move_down 20

    # Table data
    table_data = [["Consec.", "Clave", "Medidas", "P. Bruto", "P. Neto", "Metros", "Cliente"]]

    @production_order_items.each do |item|
      label_data = item.label_data
      table_data << [
        label_data[:name],
        label_data[:clave_producto],
        "#{label_data[:ancho_mm] || 0}mm / #{label_data[:micras] || 0}mic",
        label_data[:peso_bruto] ? '%.2f' % label_data[:peso_bruto] : '0.00',
        label_data[:peso_neto] ? '%.2f' % label_data[:peso_neto] : '0.00',
        label_data[:metros_lineales] ? label_data[:metros_lineales].round(2) : 0.00,
        label_data[:cliente] || 'N/A'
      ]
    end

    # Create table
    table(table_data, header: true, width: bounds.width) do
      row(0).font_style = :bold
      row(0).background_color = "F0F0F0"
      cells.padding = [5, 8]
      cells.borders = [:bottom]
      cells.border_width = 0.5
      self.row_colors = ["FFFFFF", "FDFDFD"]
    end

    @document.render
  end
end
