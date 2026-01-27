require 'rails_helper'

RSpec.describe PricesController, type: :controller do
  let(:admin) { create(:admin, email: "test@example.com", password: "password123", password_confirmation: "password123") }

  before do
    sign_in admin
  end
  describe "GET #index" do
    let(:mock_prices) do
      {
        "Oro" => { "compra" => "1500.00", "venta" => "1520.00" },
        "Plata" => { "compra" => "25.50", "venta" => "26.00" }
      }
    end

    before do
      # Mock the controller's internal method that fetches prices
      allow_any_instance_of(PricesController).to receive(:get_mock_prices).and_return(mock_prices)
    end

    it "returns http success" do
      get :index
      expect(response).to have_http_status(:success)
    end

    it "renders the index template" do
      get :index
      expect(response).to render_template(:index)
    end

    it "assigns prices" do
      get :index
      expect(assigns(:precios)).to eq(mock_prices)
    end

    it "calls the internal price fetching method" do
      expect_any_instance_of(PricesController).to receive(:get_mock_prices).and_return(mock_prices)

      get :index
    end

    context "when price fetching raises an error" do
      before do
        allow_any_instance_of(PricesController).to receive(:get_mock_prices).and_raise(StandardError.new("Price fetching error"))
      end

      it "handles the error gracefully" do
        get :index
        expect(response).to have_http_status(:success)
        expect(assigns(:precios)).to eq({})
      end
    end

    context "when price fetching returns nil" do
      before do
        allow_any_instance_of(PricesController).to receive(:get_mock_prices).and_return(nil)
      end

      it "assigns nil to @precios" do
        get :index
        expect(assigns(:precios)).to be_nil
      end
    end

    context "when price fetching returns empty hash" do
      before do
        allow_any_instance_of(PricesController).to receive(:get_mock_prices).and_return({})
      end

      it "assigns empty hash to @precios" do
        get :index
        expect(assigns(:precios)).to eq({})
      end
    end
  end
end
