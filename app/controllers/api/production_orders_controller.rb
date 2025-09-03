class Api::ProductionOrdersController < ActionController::API

  def create
    company = Company.find_by(name: params[:company_name])

    unless company
      render json: { error: "Company not found" }, status: :not_found
      return
    end

    # Assuming production_order_params will contain product_id, quantity, etc.
    # You might need to adjust these parameters based on your ProductionOrder model's requirements.
    @production_order = ProductionOrder.new(production_order_params)
    @production_order.company = company

    if @production_order.save
      render json: { message: "Production order created successfully", production_order: @production_order }, status: :created
    else
      render json: { errors: @production_order.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def production_order_params
    # Adjust these parameters based on what your ProductionOrder model requires
    # and what you expect to receive in the POST request.
    params.require(:production_order).permit(
      :product_id,
      :quantity_requested, # Assuming this is the field for quantity
      :notes,
      :status,
      :priority,
      :warehouse_id,
      :no_opro # If you want to allow setting this via API
      # Add any other fields that are required or you want to allow
    )
  end
end