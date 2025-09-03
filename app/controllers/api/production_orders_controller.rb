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
      # Send notifications to all users who should be notified about production orders
      notification_data = {
        production_order_id: @production_order.id,
        order_number: @production_order.no_opro || @production_order.order_number,
        product_name: @production_order.product.name,
        quantity: @production_order.quantity_requested,
        status: @production_order.status
      }.to_json

      # Create notifications for all relevant users in the same company
      if @production_order.company
        target_users = User.where(company: @production_order.company, role: ['admin', 'manager', 'supervisor', 'operador'])
        
        notification_records = target_users.map do |user|
          {
            user_id: user.id,
            company_id: @production_order.company_id,
            notification_type: "production_order_created",
            title: "Nueva orden de producción creada",
            message: "Se ha creado la orden de producción #{@production_order.no_opro || @production_order.order_number} para el producto #{@production_order.product.name}",
            action_url: "/admin/production_orders/#{@production_order.id}",
            data: notification_data,
            created_at: Time.current,
            updated_at: Time.current
          }
        end

        if notification_records.any?
          Notification.insert_all(notification_records)
          
          # Expire notification caches for all target users BEFORE touching them
          # This ensures we're clearing the current cache entries
          target_users.find_each do |user|
            cache_key = "notifications_data:#{user.class.name.downcase}:#{user.id}:#{user.updated_at}"
            Rails.cache.delete(cache_key)
          end
          
          # Touch user records to update their updated_at timestamps
          # This ensures new cache entries will have different keys
          target_users.find_each(&:touch)
        end
      end

      # Expire notification caches for all users in the company before broadcasting
      if @production_order.company
        User.where(company: @production_order.company, role: ['admin', 'manager', 'supervisor', 'operador']).find_each do |user|
          # Manually expire the cache by deleting the cache key
          cache_key = "notifications_data:#{user.class.name.downcase}:#{user.id}:#{user.updated_at}"
          Rails.cache.delete(cache_key)
        end
      end

      # Broadcast notifications to relevant users
      broadcast_notifications(@production_order)
      
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
  
  def broadcast_notifications(production_order)
    if production_order.company
      notification_data = {
        title: "Orden creada!",
        message: "Orden #{production_order.no_opro || production_order.order_number} para #{production_order.product.name}",
        type: "success",
        duration: 15000, # 15 seconds
        action_url: "/admin/production_orders/#{production_order.id}",
        timestamp: Time.current.iso8601
      }

      # Broadcast to company-specific channel
      broadcasting_name = "notifications:#{production_order.company.to_gid_param}"
      ActionCable.server.broadcast(
        broadcasting_name,
        {
          type: 'new_notification',
          notification: notification_data
        }
      )
    end
  end
end