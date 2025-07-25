class WebhooksController < ApplicationController
  include ApiResponses

  skip_forgery_protection only: [ :mercadopago ]
  before_action :verify_mercadopago_request, only: [ :mercadopago ]
  before_action :set_payment_id, only: [ :mercadopago ]

  def mercadopago
    result = PaymentProcessor.process_approved_payment(@payment_id)

    if result[:success]
      render_success({ message: "Payment processing initiated" })
    else
      Rails.logger.warn "Payment processing failed: #{result[:error]}. Payment ID: #{@payment_id}"
      render_error("Payment processing failed", :unprocessable_entity)
    end
  rescue StandardError => e
    Rails.logger.error "Webhook processing failed: #{e.message}. Payment ID: #{@payment_id}. Params: #{params.to_unsafe_h.inspect}"
    render_error("Internal server error", :internal_server_error)
  end

  private

  def verify_mercadopago_request
    # Basic verification - in production, implement signature validation
    unless params[:data]&.dig(:id)
      Rails.logger.warn "Invalid webhook request - missing payment ID. Params: #{params.to_unsafe_h.inspect}. Headers: #{request.headers.env.select { |k, v| k.start_with?("HTTP_") }.inspect}"
      render_error("Invalid request", :bad_request)
      return false
    end

    # TODO: Implement proper MercadoPago signature validation
    # https://www.mercadopago.com.ar/developers/es/docs/your-integrations/notifications/webhooks
    true
  end

  def set_payment_id
    @payment_id = params[:data][:id]
  end
end
