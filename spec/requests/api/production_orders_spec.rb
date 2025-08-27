require 'rails_helper'

RSpec.describe "Api::ProductionOrders", type: :request do
  describe "GET /create" do
    it "returns http success" do
      get "/api/production_orders/create"
      expect(response).to have_http_status(:success)
    end
  end

end
