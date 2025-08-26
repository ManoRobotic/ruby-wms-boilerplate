class ProductionOrderPdf
  include Prawn::View

  def initialize(production_order, production_order_items)
    @production_order = production_order
    @production_order_items = production_order_items
    @document = Prawn::Document.new
  end

  def render
    # Header
    text "Etiquetas de Consecutivos", size: 24, style: :bold, align: :center
    move_down 10

    text "Orden: #{@production_order.no_opro || @production_order.order_number}", size: 14
    text "Producto: #{@production_order.product.name}", size: 12
    text "Lote: #{@production_order.lote_referencia}", size: 12
    text "Fecha: #{Date.current.strftime('%d/%m/%Y')}", size: 12

    move_down 20

    # Create labels for each item
    @production_order_items.each_with_index do |item, index|
      # Start new page every 4 labels (2x2 grid)
      start_new_page if index > 0 && index % 4 == 0

      label_data = item.label_data

      # Calculate position (2x2 grid)
      x_position = (index % 2) * 280
      y_position = cursor - ((index % 4) / 2) * 200

      bounding_box([ x_position, y_position ], width: 260, height: 180) do
        stroke_bounds

        # Label content with padding
        indent(10, 10) do
          move_down 5

          text "CONSECUTIVO: #{label_data[:name]}", size: 11, style: :bold
          move_down 5

          text "Lote: #{label_data[:lote]}", size: 9
          text "Clave: #{label_data[:clave_producto]}", size: 9
          move_down 3

          if label_data[:peso_bruto].present?
            text "Peso Bruto: #{label_data[:peso_bruto]} kg", size: 9
          end

          if label_data[:peso_neto].present?
            text "Peso Neto: #{label_data[:peso_neto]} kg", size: 9
          end

          if label_data[:metros_lineales].present?
            text "Metros: #{label_data[:metros_lineales]} m", size: 9
          end

          move_down 3
          text "Cliente: #{label_data[:cliente] || 'N/A'}", size: 8
          text "Orden: #{label_data[:numero_de_orden]}", size: 8

          move_down 5
          text Date.current.strftime("%d/%m/%Y"), size: 7, align: :right
        end
      end
    end

    @document.render
  end
end
