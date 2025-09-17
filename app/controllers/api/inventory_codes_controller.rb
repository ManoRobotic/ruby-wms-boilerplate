class Api::InventoryCodesController < ActionController::API
  def create
    # Map API parameter names to model field names
    mapped_params = map_api_params_to_model_fields(params[:inventory_code] || {})
    
    # Sanitize parameters using strong parameters
    begin
      sanitized_params = sanitize_inventory_code_params(mapped_params)
    rescue ActionController::ParameterMissing => e
      render json: { errors: [ "Missing required parameter: #{e.param}" ] }, status: :bad_request
      return
    end

    # Create a new inventory code with the provided parameters
    @inventory_code = InventoryCode.new(sanitized_params)

    if @inventory_code.save
      render json: { 
        message: "Inventory code created successfully", 
        inventory_code: @inventory_code 
      }, status: :created
    else
      render json: { 
        errors: @inventory_code.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end

  def batch
    # Extract inventory codes from params
    codes_params = params[:inventory_codes] || []

    if codes_params.empty?
      render json: { error: "No inventory codes provided" }, status: :bad_request
      return
    end

    # Process each code and collect results
    results = []
    success_count = 0
    codes_params.each_with_index do |code_params, index|
      # Create a new inventory code with the provided parameters
      inventory_code = InventoryCode.new

      # Map API parameter names to model field names
      mapped_params = map_api_params_to_model_fields(code_params)
      
      # Sanitize parameters using strong parameters
      begin
        sanitized_params = sanitize_inventory_code_params(mapped_params)
        inventory_code.assign_attributes(sanitized_params)
      rescue ActionController::ParameterMissing => e
        results << {
          index: index,
          status: "error",
          errors: [ "Missing required parameter: #{e.param}" ]
        }
        next
      end

      if inventory_code.save
        success_count += 1
        results << {
          index: index,
          status: "success",
          message: "Inventory code created successfully",
          inventory_code: {
            id: inventory_code.id,
            no_ordp: inventory_code.no_ordp,
            cve_copr: inventory_code.cve_copr,
            cve_prod: inventory_code.cve_prod
          }
        }
      else
        results << {
          index: index,
          status: "error",
          errors: inventory_code.errors.full_messages
        }
      end
    end

    # Return all results
    render json: {
      message: "Batch processing completed",
      success_count: success_count,
      total_count: codes_params.length,
      results: results
    }, status: :ok
  end

  private

  def inventory_code_params
    params.require(:inventory_code).permit(
      :no_ordp,        # No. Orden
      :cve_copr,       # Código Componente
      :cve_prod,       # Código Producto
      :can_copr,       # Cantidad
      :costo,          # Costo
      :lote,           # Lote
      :fech_cto,       # Fecha
      :tip_copr        # Estado (1 = Activo, 0 = Inactivo)
    )
  end

  def map_api_params_to_model_fields(code_params)
    # Map API parameter names to model field names
    mapped_params = code_params.dup
    
    # Handle date parameter if provided as string
    if mapped_params[:fecha].present?
      begin
        mapped_params[:fech_cto] = Date.parse(mapped_params[:fecha])
      rescue Date::Error
        # If parsing fails, we'll let the model validation handle it
      end
      mapped_params.delete(:fecha)
    end
    
    # Handle status mapping if provided as string
    if mapped_params[:estado].present?
      case mapped_params[:estado].to_s.downcase
      when "activo"
        mapped_params[:tip_copr] = 1
      when "inactivo"
        mapped_params[:tip_copr] = 0
      else
        # Try to convert to integer
        status_value = mapped_params[:estado].to_i
        mapped_params[:tip_copr] = status_value if [0, 1].include?(status_value)
      end
      mapped_params.delete(:estado)
    end
    
    mapped_params
  end

  def sanitize_inventory_code_params(code_params)
    # Create a fake params object to use with strong parameters
    fake_params = ActionController::Parameters.new(inventory_code: code_params)
    fake_params.require(:inventory_code).permit(
      :no_ordp,
      :cve_copr,
      :cve_prod,
      :can_copr,
      :costo,
      :lote,
      :fech_cto,
      :tip_copr
    )
  end
end