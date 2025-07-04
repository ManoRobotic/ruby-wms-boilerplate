require 'rails_helper'

RSpec.describe 'Checkouts', type: :request do
  describe 'POST /checkout' do
    let(:category) { create(:category, :electronics) }
    let(:product) { create(:product, :with_stock, category: category) }
    let(:checkout_params) do
      {
        customer_email: 'test@example.com',
        address: '123 Test St, Test City',
        products: [
          {
            id: product.id,
            quantity: 2,
            size: 'M'
          }
        ]
      }
    end

    context 'with valid parameters' do
      before do
        allow(CartProcessor).to receive(:process_checkout).and_return(
          double(success?: true, order: create(:order), message: 'Order created successfully', payment_url: nil)
        )
      end

      it 'creates a new order successfully' do
        post '/checkout', params: checkout_params

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to('/checkout/success')
      end

      it 'processes checkout with CartProcessor' do
        # Rails converts the parameters to strings, so we need to expect the string version
        expected_params = {
          customer_email: 'test@example.com',
          address: '123 Test St, Test City',
          products: [
            {
              'id' => product.id,
              'quantity' => '2',
              'size' => 'M'
            }
          ]
        }
        expect(CartProcessor).to receive(:process_checkout).with(expected_params)

        post '/checkout', params: checkout_params
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          customer_email: 'invalid-email',
          address: '',
          products: []
        }
      end

      before do
        allow(CartProcessor).to receive(:process_checkout).and_return(
          double(success?: false, errors: [ 'Invalid email format', 'Address is required' ])
        )
      end

      it 'returns validation errors' do
        post '/checkout', params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Invalid email format')
        expect(response.body).to include('Address is required')
      end
    end

    context 'with insufficient stock' do
      let(:out_of_stock_product) { create(:product, :out_of_stock) }
      let(:insufficient_stock_params) do
        {
          customer_email: 'test@example.com',
          address: '123 Test St',
          products: [
            {
              id: out_of_stock_product.id,
              quantity: 1,
              size: 'M'
            }
          ]
        }
      end

      before do
        allow(CartProcessor).to receive(:process_checkout).and_return(
          double(success?: false, errors: [ 'Insufficient stock for product' ])
        )
      end

      it 'handles insufficient stock gracefully' do
        post '/checkout', params: insufficient_stock_params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Insufficient stock')
      end
    end

    context 'with MercadoPago integration' do
      let(:mock_payment_response) do
        {
          'id' => 'MP-12345',
          'status' => 'pending',
          'init_point' => 'https://mercadopago.com/checkout/123'
        }
      end

      before do
        allow(CartProcessor).to receive(:process_checkout).and_return(
          double(
            success?: true,
            order: create(:order, payment_id: 'MP-12345'),
            payment_url: 'https://mercadopago.com/checkout/123'
          )
        )
      end

      it 'redirects to MercadoPago for payment' do
        post '/checkout', params: checkout_params

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('mercadopago.com')
      end
    end
  end

  describe 'GET /checkout/success' do
    let(:order) { create(:order, :processing, payment_id: 'MP-12345') }

    it 'displays success page' do
      get '/checkout/success'

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Thank you for your order')
    end

    it 'clears the order from session' do
      # Set session via a POST request that would set the session
      allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:last_order_id).and_return(order.id)
      allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]=).with(:last_order_id, nil)
      
      get '/checkout/success'

      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /checkout/failure' do
    it 'displays failure page' do
      get '/checkout/failure'

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Payment failed')
      expect(response.body).to include('Try again')
    end
  end

  describe 'GET /checkout/pending' do
    it 'displays pending page' do
      get '/checkout/pending'

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Payment pending')
      expect(response.body).to include('We will notify you')
    end
  end

  describe 'cart calculations' do
    let(:expensive_product) { create(:product, :expensive, :with_stock) }
    let(:cheap_product) { create(:product, :cheap, :with_stock) }
    let(:multi_product_params) do
      {
        customer_email: 'test@example.com',
        address: '123 Test St',
        products: [
          { id: expensive_product.id, quantity: 1, size: 'L' },
          { id: cheap_product.id, quantity: 3, size: 'S' }
        ]
      }
    end

    it 'calculates total correctly for multiple products' do
      expected_total = expensive_product.price + (cheap_product.price * 3)

      # Mock the CartProcessor to return a payment URL
      allow(CartProcessor).to receive(:process_checkout).and_return(
        double(success?: true, payment_url: 'https://mercadopago.com/pay/123')
      )

      post '/checkout', params: multi_product_params

      expect(response).to redirect_to('https://mercadopago.com/pay/123')
    end
  end
end
