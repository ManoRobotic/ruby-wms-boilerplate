require 'rails_helper'

RSpec.describe CheckoutsController, type: :controller do
  let(:product) { create(:product) }
  let(:stock) { create(:stock, product: product, size: "M", amount: 10) }

  before do
    stock
  end

  describe "POST #create" do
    let(:valid_cart_params) do
      {
        customer_email: "test@example.com",
        address: "123 Main St",
        products: [
          {
            id: product.id.to_s,
            quantity: "2",
            size: "M"
          }
        ]
      }
    end

    context "with valid parameters and sufficient stock" do
      before do
        allow(CartProcessor).to receive(:process_checkout).and_return(
          double(success?: true, payment_url: "https://payment-url.com")
        )
      end

      it "redirects to payment URL" do
        post :create, params: valid_cart_params
        expect(response).to redirect_to("https://payment-url.com")
      end

      it "calls CartProcessor with correct parameters" do
        expected_params = {
          customer_email: "test@example.com",
          address: "123 Main St",
          products: [
            {
              "id" => product.id.to_s,
              "quantity" => "2",
              "size" => "M"
            }
          ]
        }

        expect(CartProcessor).to receive(:process_checkout)
          .with(expected_params)
          .and_return(double(success?: true, payment_url: "https://payment-url.com"))

        post :create, params: valid_cart_params
      end
    end

    context "with insufficient stock" do
      let(:insufficient_cart_params) do
        {
          customer_email: "test@example.com",
          address: "123 Main St",
          products: [
            {
              id: product.id.to_s,
              quantity: "15",
              size: "M"
            }
          ]
        }
      end

      before do
        allow(CartProcessor).to receive(:process_checkout).and_return(
          double(success?: false, errors: [ "Insufficient stock" ])
        )
      end

      it "returns unprocessable entity status with error message" do
        post :create, params: insufficient_cart_params, format: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["error"]).to include("Insufficient stock")
      end
    end

    context "when CartProcessor fails" do
      before do
        allow(CartProcessor).to receive(:process_checkout).and_return(
          double(success?: false, errors: [ "Payment service error" ])
        )
      end

      it "returns unprocessable entity with error message" do
        post :create, params: valid_cart_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Payment service error")
      end
    end

    context "when payment URL is blank" do
      before do
        allow(CartProcessor).to receive(:process_checkout).and_return(
          double(success?: true, payment_url: nil)
        )
      end

      it "redirects to success page" do
        post :create, params: valid_cart_params
        expect(response).to redirect_to('/checkout/success')
      end
    end
  end

  describe "GET #success" do
    let(:success_params) do
      {
        payment_id: "123456",
        status: "approved",
        external_reference: "ref123",
        merchant_order_id: "order123"
      }
    end

    it "returns http success" do
      get :success, params: success_params
      expect(response).to have_http_status(:success)
    end

    it "renders the success template" do
      get :success, params: success_params
      expect(response).to render_template(:success)
    end
  end

  describe "GET #failure" do
    it "returns http success" do
      get :failure
      expect(response).to have_http_status(:success)
    end

    it "renders the failure template" do
      get :failure
      expect(response).to render_template(:failure)
    end
  end

  describe "GET #pending" do
    it "returns http success" do
      get :pending
      expect(response).to have_http_status(:success)
    end

    it "renders the pending template" do
      get :pending
      expect(response).to render_template(:pending)
    end
  end
end
