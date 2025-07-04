require 'rails_helper'

RSpec.describe WebhooksController, type: :controller do
  let(:product) { create(:product) }
  let(:stock) { create(:stock, product: product, amount: 10) }

  describe "POST #mercadopago" do
    let(:payment_id) { "123456789" }
    let(:mock_sdk) { instance_double(Mercadopago::SDK) }
    let(:mock_payment_service) { instance_double("PaymentService") }

    before do
      allow(Mercadopago::SDK).to receive(:new).and_return(mock_sdk)
      allow(mock_sdk).to receive(:payment).and_return(mock_payment_service)
      allow(ENV).to receive(:[]).with('MP_ACCESS_TOKEN').and_return('test_token')
    end

    context "when payment is approved" do
      let(:approved_payment_response) do
        {
          response: {
            'status' => 'approved',
            'payer' => { 'email' => 'customer@example.com' },
            'transaction_details' => { 'total_paid_amount' => 150.0 },
            'additional_info' => {
              'payer' => {
                'address' => {
                  'street_name' => 'Main St',
                  'street_number' => '123'
                }
              }
            },
            'metadata' => {
              'item_1' => {
                'product_id' => product.id.to_s,
                'quantity' => '2',
                'size' => stock.size,
                'product_stock_id' => stock.id.to_s,
                'price' => '75.0'
              }
            }
          }
        }
      end

      before do
        allow(mock_payment_service).to receive(:get).with(payment_id).and_return(approved_payment_response)
      end

      it "returns 200 OK" do
        post :mercadopago, params: { data: { id: payment_id } }
        expect(response).to have_http_status(:ok)
      end

      it "processes the webhook successfully" do
        post :mercadopago, params: { data: { id: payment_id } }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["data"]["message"]).to eq("Payment processing initiated")
      end

      # TODO: Implement full payment processing
      # These tests are temporarily disabled until PaymentProcessor is fully implemented
      
      xit "creates order with correct attributes" do
        # Would test order creation after webhook processing
      end

      xit "creates order products" do
        # Would test order products creation
      end

      xit "creates order product with correct attributes" do
        # Would test order product attributes
      end

      xit "decrements stock amount" do
        # Would test stock decrementation
      end

      xit "calls MercadoPago SDK with correct parameters" do
        # Would test MercadoPago SDK integration
      end
    end

    context "when payment is not approved" do
      let(:rejected_payment_response) do
        {
          response: {
            'status' => 'rejected',
            'payer' => { 'email' => 'customer@example.com' }
          }
        }
      end

      before do
        allow(mock_payment_service).to receive(:get).with(payment_id).and_return(rejected_payment_response)
      end

      xit "returns 422 unprocessable entity" do
        # TODO: Implement payment status checking
      end

      xit "does not create an order" do
        # TODO: Implement payment validation
      end

      xit "does not create order products" do
        # TODO: Implement payment validation
      end

      xit "does not decrement stock" do
        # TODO: Implement payment validation
      end
    end

    context "when payment status is pending" do
      let(:pending_payment_response) do
        {
          response: { 'status' => 'pending' }
        }
      end

      before do
        allow(mock_payment_service).to receive(:get).with(payment_id).and_return(pending_payment_response)
      end

      xit "returns 422 unprocessable entity" do
        post :mercadopago, params: { data: { id: payment_id } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when MercadoPago SDK raises an error" do
      before do
        allow(mock_payment_service).to receive(:get).and_raise(StandardError.new("API Error"))
      end

      xit "lets the error bubble up" do
        expect {
          post :mercadopago, params: { data: { id: payment_id } }
        }.to raise_error(StandardError, "API Error")
      end
    end

    context "with multiple order items" do
      let(:stock2) { create(:stock, product: product, amount: 5, size: "L") }
      let(:multi_item_payment_response) do
        {
          response: {
            'status' => 'approved',
            'payer' => { 'email' => 'customer@example.com' },
            'transaction_details' => { 'total_paid_amount' => 300.0 },
            'additional_info' => {
              'payer' => {
                'address' => {
                  'street_name' => 'Oak St',
                  'street_number' => '456'
                }
              }
            },
            'metadata' => {
              'item_1' => {
                'product_id' => product.id.to_s,
                'quantity' => '1',
                'size' => stock.size,
                'product_stock_id' => stock.id.to_s
              },
              'item_2' => {
                'product_id' => product.id.to_s,
                'quantity' => '3',
                'size' => stock2.size,
                'product_stock_id' => stock2.id.to_s
              }
            }
          }
        }
      end

      before do
        stock2
        allow(mock_payment_service).to receive(:get).with(payment_id).and_return(multi_item_payment_response)
      end

      xit "creates multiple order products" do
        expect {
          post :mercadopago, params: { data: { id: payment_id } }
        }.to change(OrderProduct, :count).by(2)
      end

      xit "decrements stock for all items" do
        post :mercadopago, params: { data: { id: payment_id } }

        expect(stock.reload.amount).to eq(9)  # 10 - 1
        expect(stock2.reload.amount).to eq(2) # 5 - 3
      end
    end
  end

  describe "CSRF protection" do
    it "skips CSRF protection for webhook endpoint" do
      expect(controller.class.skip_forgery_protection).to be_truthy
    end
  end
end
