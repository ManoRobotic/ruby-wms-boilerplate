require "roo"

class ExcelImportService
  def initialize(file_path)
    @file_path = file_path
    @spreadsheet = Roo::Spreadsheet.open(file_path)
  end

  def import_production_orders
    results = {
      created: 0,
      updated: 0,
      errors: []
    }

    # Usar la hoja ORDEN PRODUCCION del nuevo archivo
    sheet = @spreadsheet.sheet("ORDEN PRODUCCION")

    # Obtener headers (fila 1)
    headers = sheet.row(1)
    puts "Headers encontrados: #{headers}"

    # Procesar cada fila (empezando desde la fila 2)
    (2..sheet.last_row).each do |row_num|
      row_data = sheet.row(row_num)
      next if row_data.compact.empty? # Saltar filas vacías

      begin
        production_order_data = map_row_to_production_order(headers, row_data)
        next if production_order_data.nil? # Saltar si los datos no son válidos

        # Buscar o crear ProductionOrder
        production_order = find_or_create_production_order(production_order_data)

        if production_order.persisted?
          if production_order.previously_new_record?
            results[:created] += 1
          else
            results[:updated] += 1
          end
        else
          results[:errors] << {
            row: row_num,
            data: production_order_data,
            errors: production_order.errors.full_messages
          }
        end

      rescue => e
        results[:errors] << {
          row: row_num,
          data: row_data,
          error: e.message
        }
      end
    end

    results
  end

  private

  def map_row_to_production_order(headers, row_data)
    # Mapear las columnas del Excel ordproc a los campos del modelo ProductionOrder
    data = {}
    headers.each_with_index do |header, index|
      value = row_data[index]
      next if value.blank?

      # Mapeo basado en las columnas del nuevo archivo FE BASE DE DATOS.xlsx
      case header&.to_s&.upcase&.strip
      when "NO_ORDP(ORDPROC)", "ID ORD PROD"
        data[:order_number] = "OP-#{value}"
      when "CLAVE_COPR"
        # Buscar o crear producto por nombre
        begin
          product = Product.find_by(name: value.to_s)
          if product.nil?
            # Asegurar que existe al menos una categoría
            category = Category.first
            if category.nil?
              category = Category.create!(
                name: "Productos Importados",
                description: "Categoría por defecto para productos importados"
              )
            end

            product = Product.create!(
              name: value.to_s,
              description: "Producto importado desde Excel: #{value}",
              price: 1.0,  # Precio mínimo por validación
              category: category,
              active: true
            )
          end
          data[:product_id] = product.id
        rescue => e
          puts "Error creando producto #{value}: #{e.message}"
          data[:product_id] = nil
        end
      when "CVE_SUC"
        # Buscar o crear almacén por código
        begin
          warehouse = Warehouse.find_by(code: value.to_s)
          if warehouse.nil?
            warehouse = Warehouse.create!(
              code: value.to_s,
              name: "Almacén #{value}",
              address: "Dirección por definir"
            )
          end
          data[:warehouse_id] = warehouse.id
        rescue => e
          puts "Error creando almacén #{value}: #{e.message}"
          data[:warehouse_id] = nil
        end
      when "REN_COPR(CANTIDAD)"
        data[:quantity_requested] = value.to_f.to_i
      when "ESTATUS"
        data[:status] = map_status(value.to_s)
      when "FECH_ORDP"
        data[:start_date] = parse_date(value)
      when "LOTE(ELLOS LLENAN)"
        data[:lote_referencia] = value.to_s if value.present?
      when "NO OPRO"
        data[:no_opro] = value.to_s if value.present?
      when "CARGA_COPR"
        data[:carga_copr] = value.to_f if value.present?
      when "ANO"
        data[:ano] = value.to_i if value.present?
      when "MES"
        data[:mes] = value.to_i if value.present?
      when "FECHA TOTAL", "FECHA_C"
        data[:fecha_completa] = parse_date(value) if value.present?
      when "PESO"
        data[:peso] = value.to_f if value.present?
      end
    end

    # Valores por defecto
    data[:status] ||= "pending"
    data[:priority] ||= "medium"
    data[:admin_id] = "1" # Usuario por defecto, puedes ajustar según necesites

    # Asegurar que tenemos un almacén por defecto si no se especifica
    if data[:warehouse_id].blank?
      default_warehouse = Warehouse.first
      if default_warehouse.nil?
        default_warehouse = Warehouse.create!(
          code: "DEFAULT",
          name: "Almacén Principal",
          address: "Dirección por definir"
        )
      end
      data[:warehouse_id] = default_warehouse.id
    end

    # Asegurar que tenemos los campos requeridos
    if data[:order_number].blank?
      data[:order_number] = generate_order_number
    end

    # Validar campos requeridos
    if data[:product_id].blank? || data[:quantity_requested].blank? || data[:quantity_requested] <= 0
      puts "Saltando fila por datos incompletos: producto=#{data[:product_id]}, cantidad=#{data[:quantity_requested]}"
      return nil
    end

    data
  end

  def find_or_create_production_order(data)
    # Buscar por order_number si existe
    if data[:order_number].present?
      production_order = ProductionOrder.find_or_initialize_by(
        order_number: data[:order_number]
      )
      production_order.assign_attributes(data)
    else
      # Si no hay order_number, generar uno
      data[:order_number] = generate_order_number
      production_order = ProductionOrder.new(data)
    end

    production_order.save
    production_order
  end

  def generate_order_number
    "PO#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
  end

  def map_priority(value)
    case value.to_s.downcase.strip
    when "alta", "high", "urgent", "urgente"
      "high"
    when "media", "medium", "normal"
      "medium"
    when "baja", "low"
      "low"
    else
      "medium"
    end
  end

  def map_status(value)
    case value.to_s.downcase.strip
    when "emitida", "pending", "nuevo"
      "pending"
    when "programado", "scheduled"
      "scheduled"
    when "en_proceso", "in_progress", "iniciado", "en proceso"
      "in_progress"
    when "pausado", "paused"
      "paused"
    when "completado", "completed", "terminado", "terminada"
      "completed"
    when "cancelado", "cancelled", "cancelada"
      "cancelled"
    else
      "pending"
    end
  end

  def parse_date(value)
    return nil if value.blank? || value.to_s.downcase == "none"

    case value
    when Date, Time, DateTime
      value
    when String
      begin
        Date.parse(value.to_s)
      rescue ArgumentError
        nil
      end
    else
      begin
        # Para fechas serializadas de Excel
        Date.parse(value.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
