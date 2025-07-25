class PaymentProcessor
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :payment_data

  def self.process_approved_payment(payment_id)
    payment_data = fetch_payment_data(payment_id)
    new(payment_data: payment_data).process
  end

  def self.fetch_payment_data(payment_id)
    # Fetch payment data from MercadoPago
    sdk = Mercadopago::SDK.new(ENV["MP_ACCESS_TOKEN"])
    response = sdk.payment.get(payment_id)
    response.response
  end

  def initialize(payment_data:)
    @payment_data = payment_data
  end

  def process
    return { success: false, error: "Payment not approved" } unless payment_approved?

    ActiveRecord::Base.transaction do
      order = create_order
      create_order_products(order)
      update_stock_levels
      log_successful_payment(order)
      { success: true, order: order }
    end
  rescue StandardError => e
    Rails.logger.error "Payment processing failed: #{e.message}. Payment ID: #{payment_id}. Backtrace: #{e.backtrace.first(5).join(', ')}"
    { success: false, error: e.message }
  end

  private

  def payment_approved?
    payment_data&.dig("status") == "approved"
  end

  def payment_id
    payment_data&.dig("id")
  end

  def create_order
    Order.create!(
      customer_email: payment_data.dig("payer", "email"),
      total: payment_data.dig("transaction_details", "total_paid_amount"),
      address: build_address,
      status: :pending,
      payment_id: payment_id
    )
  end

  def build_address
    address_info = payment_data.dig("additional_info", "payer", "address")
    return "Address not provided" unless address_info

    "#{address_info['street_name']} #{address_info['street_number']}"
  end

  def create_order_products(order)
    line_items = payment_data.dig("metadata")&.values || []

    line_items.each do |item|
      OrderProduct.create!(
        order: order,
        product_id: item["product_id"],
        quantity: item["quantity"].to_i,
        size: item["size"],
        unit_price: item["price"]&.to_f || 0.0
      )
    end
  end

  def update_stock_levels
    line_items = payment_data.dig("metadata")&.values || []

    line_items.each do |item|
      stock = Stock.find(item["product_stock_id"])
      stock.decrement!(:amount, item["quantity"].to_i)
    end
  end

  def log_successful_payment(order)
    Rails.logger.info "Payment processed successfully - Payment ID: #{payment_id}, Order ID: #{order.id}, Amount: #{order.total}, Customer: #{order.customer_email}"
  end
end
