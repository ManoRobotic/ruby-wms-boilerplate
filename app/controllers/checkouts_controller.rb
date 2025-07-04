class CheckoutsController < ApplicationController
  include ApiResponses

  def create
    result = CartProcessor.process_checkout(checkout_params)

    if result.success?
      if result.payment_url.present?
        redirect_to result.payment_url, allow_other_host: true
      else
        redirect_to '/checkout/success'
      end
    else
      respond_to do |format|
        format.html { 
          flash[:alert] = result.errors.join(', ')
          render plain: result.errors.join(', '), status: :unprocessable_entity
        }
        format.json { render_error(result.errors.join(', '), :unprocessable_entity) }
      end
    end
  end

  def success
    Rails.logger.info "Checkout success - Payment ID: #{params[:payment_id]}, Status: #{params[:status]}, External Ref: #{params[:external_reference]}, Merchant Order: #{params[:merchant_order_id]}"
    
    @order = Order.find(session[:last_order_id]) if session[:last_order_id]
    session[:last_order_id] = nil
    
    render :success
  end

  def failure
    Rails.logger.info "Checkout failure - Payment ID: #{params[:payment_id]}, Status: #{params[:status]}"

    render :failure
  end

  def pending
    Rails.logger.info "Checkout pending - Payment ID: #{params[:payment_id]}, Status: #{params[:status]}"

    render :pending
  end

  private

  def checkout_params
    products = if params[:products].is_a?(Array) && params[:products].present?
                 params[:products].map do |p|
                   if p.respond_to?(:permit)
                     p.permit(:id, :quantity, :size).to_h
                   elsif p.respond_to?(:to_h)
                     p.to_h.symbolize_keys  # Convert string keys to symbols for test compatibility
                   else
                     p # Handle strings or other types
                   end
                 end
               else
                 params[:products] || []  # Return empty array for empty products
               end
               
    {
      customer_email: params[:customer_email],
      address: params[:address],
      products: products
    }
  end
end
