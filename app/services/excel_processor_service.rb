class ExcelProcessorService
  require 'roo'
  
  def initialize(file_path = nil)
    @merged_file_path = file_path || 'merged.xlsx'
    @fe_file_path = 'FE BASE DE DATOS.xlsx'
  end
  
  # Main method to process and generate production orders from merged.xlsx
  def process_merged_file
    validate_files_exist
    
    Rails.logger.info "Processing merged.xlsx file..."
    
    # Process production orders from opro sheet
    production_orders = process_opro_sheet
    Rails.logger.info "Processed #{production_orders.count} production orders"
    
    # Process packing records from FE database
    packing_records = process_fe_packing_data
    Rails.logger.info "Processed #{packing_records.count} packing records"
    
    {
      production_orders: production_orders,
      packing_records: packing_records
    }
  end
  
  # Process production orders from opro sheet
  def process_opro_sheet
    results = []
    merged_file = Roo::Spreadsheet.open(@merged_file_path)
    merged_file.default_sheet = "opro - Sheet"
    
    # Get default warehouse for now (you may want to make this configurable)
    warehouse = Warehouse.first || create_default_warehouse
    
    (2..merged_file.last_row).each do |row_num|
      row_data = merged_file.row(row_num)
      
      # Skip if essential data is missing
      next if row_data[0].blank? || row_data[3].blank?
      
      production_order_data = extract_production_order_data(row_data)
      
      # Find or create product based on CVE_PROP
      product = find_or_create_product(production_order_data[:cve_prop])
      
      # Create or update production order
      production_order = create_or_update_production_order(
        production_order_data,
        warehouse,
        product
      )
      
      results << production_order if production_order
    end
    
    results
  end
  
  # Process packing data from FE database
  def process_fe_packing_data
    return [] unless File.exist?(@fe_file_path)
    
    results = []
    fe_file = Roo::Spreadsheet.open(@fe_file_path)
    
    # Process PACKING sheet
    if fe_file.sheets.include?("PACKING")
      fe_file.default_sheet = "PACKING"
      results += process_packing_sheet(fe_file)
    end
    
    # Process IMPRESION sheet as backup
    if fe_file.sheets.include?("IMPRESION")
      fe_file.default_sheet = "IMPRESION"
      results += process_impresion_sheet(fe_file)
    end
    
    results
  end
  
  private
  
  def validate_files_exist
    unless File.exist?(@merged_file_path)
      raise "Merged file not found: #{@merged_file_path}"
    end
    
    Rails.logger.warn "FE database file not found: #{@fe_file_path}" unless File.exist?(@fe_file_path)
  end
  
  def extract_production_order_data(row_data)
    {
      no_opro: row_data[0],
      cve_suc: row_data[1],
      fec_opro: row_data[2],
      cve_prop: row_data[3],
      ren_opro: row_data[4],
      carga_opro: row_data[5],
      stat_opro: row_data[8],
      lote: row_data[17],
      referencia: row_data[19],
      observa: row_data[25],
      mes: row_data[13],
      ano: row_data[14]
    }
  end
  
  def find_or_create_product(cve_prop)
    # Find existing product by name or create new one
    product = Product.find_by(name: cve_prop)
    
    unless product
      begin
        # Create default category if needed
        category = Category.first || Category.create!(
          name: "Productos BOPP",
          description: "Productos de polipropileno biorientado"
        )
        
        # Extract micras and width from CVE_PROP
        micras, width = parse_cve_prop(cve_prop)
        
        product = Product.create!(
          name: cve_prop,
          description: generate_product_description(cve_prop, micras, width),
          category: category,
          sku: generate_sku(cve_prop),
          active: true,
          price: 0.0  # Default price
        )
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "Error creating product #{cve_prop}: #{e.message}"
        # Try to find if it was created by another process
        product = Product.find_by(name: cve_prop)
        # If still not found, create a basic one
        unless product
          product = Product.create!(
            name: cve_prop[0..49], # Truncate if too long
            description: "Auto-generated product",
            category: Category.first,
            price: 0.0,
            active: true
          )
        end
      end
    end
    
    product
  end
  
  def parse_cve_prop(cve_prop)
    # Parse format like "BOPPTRANS 35 / 420" to extract 35 (micras) and 420 (width)
    match = cve_prop.match(/(\d+)\s*\/\s*(\d+)/)
    if match
      [match[1].to_i, match[2].to_i]
    else
      [nil, nil]
    end
  end
  
  def generate_product_description(cve_prop, micras, width)
    desc = "BOPP Transparente"
    desc += " #{micras} micras" if micras
    desc += " #{width}mm ancho" if width
    desc
  end
  
  def generate_sku(cve_prop)
    # Generate SKU from CVE_PROP
    cve_prop.gsub(/[^A-Z0-9]/, '')[0..20]
  end
  
  def create_or_update_production_order(data, warehouse, product)
    # Find existing by NO_OPRO or create new
    production_order = ProductionOrder.find_by(no_opro: data[:no_opro])
    
    if production_order
      update_existing_production_order(production_order, data)
    else
      create_new_production_order(data, warehouse, product)
    end
  end
  
  def create_new_production_order(data, warehouse, product)
    status = map_status(data[:stat_opro])
    priority = "medium" # Default priority
    
    ProductionOrder.create!(
      warehouse: warehouse,
      product: product,
      quantity_requested: data[:ren_opro]&.to_i || 0,
      status: status,
      priority: priority,
      estimated_completion: parse_date(data[:fec_opro]),
      notes: data[:observa],
      lote_referencia: data[:lote],
      no_opro: data[:no_opro],
      carga_copr: data[:carga_opro],
      ano: data[:ano],
      mes: data[:mes],
      fecha_completa: parse_date(data[:fec_opro])
    )
  rescue => e
    Rails.logger.error "Error creating production order: #{e.message}"
    Rails.logger.error "Data: #{data}"
    nil
  end
  
  def update_existing_production_order(production_order, data)
    production_order.update!(
      quantity_requested: data[:ren_opro]&.to_i || production_order.quantity_requested,
      status: map_status(data[:stat_opro]) || production_order.status,
      notes: data[:observa] || production_order.notes,
      carga_copr: data[:carga_opro] || production_order.carga_copr
    )
    production_order
  rescue => e
    Rails.logger.error "Error updating production order: #{e.message}"
    production_order
  end
  
  def map_status(stat_opro)
    case stat_opro&.downcase
    when "terminada", "completed"
      "completed"
    when "cancelada", "cancelled"
      "cancelled"
    when "en proceso", "in_progress"
      "in_progress"
    else
      "pending"
    end
  end
  
  def parse_date(date_value)
    return nil if date_value.blank?
    
    if date_value.is_a?(Date)
      date_value
    elsif date_value.is_a?(String)
      Date.parse(date_value) rescue nil
    else
      nil
    end
  end
  
  def process_packing_sheet(fe_file)
    results = []
    
    (2..fe_file.last_row).each do |row_num|
      row_data = fe_file.row(row_num)
      
      # Skip empty rows
      next if row_data[0].blank?
      
      packing_data = extract_packing_data(row_data)
      packing_record = create_packing_record(packing_data)
      
      results << packing_record if packing_record
    end
    
    results
  end
  
  def process_impresion_sheet(fe_file)
    results = []
    
    (2..fe_file.last_row).each do |row_num|
      row_data = fe_file.row(row_num)
      
      # Skip empty rows
      next if row_data[0].blank?
      
      packing_data = extract_impresion_data(row_data)
      packing_record = create_packing_record(packing_data)
      
      results << packing_record if packing_record
    end
    
    results
  end
  
  def extract_packing_data(row_data)
    # Based on PACKING sheet structure
    {
      consecutivo: row_data[1],
      lote: row_data[2],
      cve_prod: row_data[3],
      peso_bruto: row_data[4],
      peso_neto: row_data[5],
      metros_lineales: row_data[6],
      cliente: row_data[7],
      descripcion: row_data[8],
      num_orden: row_data[9]
    }
  end
  
  def extract_impresion_data(row_data)
    # Based on IMPRESION sheet structure
    {
      consecutivo: row_data[2],
      lote_padre: row_data[3],
      lote: row_data[4],
      cve_prod: row_data[5],
      peso_bruto: row_data[8],
      peso_neto: row_data[9], # Assuming peso bascula is peso neto
      metros_lineales: nil # Not available in impresion sheet
    }
  end
  
  def create_packing_record(data)
    return nil if data[:lote].blank? || data[:cve_prod].blank?
    
    # Find associated production order
    production_order = find_production_order_for_packing(data)
    return nil unless production_order
    
    # Check if record already exists
    existing = PackingRecord.find_by(
      production_order: production_order,
      consecutivo: data[:consecutivo],
      lote: data[:lote]
    )
    
    return existing if existing
    
    PackingRecord.create!(
      production_order: production_order,
      lote_padre: data[:lote_padre],
      lote: data[:lote],
      cve_prod: data[:cve_prod],
      peso_bruto: data[:peso_bruto],
      peso_neto: data[:peso_neto],
      metros_lineales: data[:metros_lineales],
      consecutivo: data[:consecutivo] || 1,
      cliente: data[:cliente],
      descripcion: data[:descripcion],
      num_orden: data[:num_orden],
      nombre: data[:cliente] || data[:descripcion]
    )
  rescue => e
    Rails.logger.error "Error creating packing record: #{e.message}"
    Rails.logger.error "Data: #{data}"
    nil
  end
  
  def find_production_order_for_packing(data)
    # Try to find by product name (cve_prod)
    product = Product.find_by(name: data[:cve_prod])
    return nil unless product
    
    # Find the most recent production order for this product
    ProductionOrder.joins(:product)
                   .where(product: product)
                   .order(created_at: :desc)
                   .first
  end
  
  def create_default_warehouse
    Warehouse.create!(
      name: "Almacén Principal",
      code: "MAIN",
      address: "Dirección principal"
    )
  end
end