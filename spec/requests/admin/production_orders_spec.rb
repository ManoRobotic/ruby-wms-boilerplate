require 'rails_helper'

RSpec.describe "Admin::ProductionOrders", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/admin/production_orders/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/admin/production_orders/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/admin/production_orders/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/admin/production_orders/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      get "/admin/production_orders/edit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http success" do
      get "/admin/production_orders/update"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/admin/production_orders/destroy"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /start" do
    it "returns http success" do
      get "/admin/production_orders/start"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /pause" do
    it "returns http success" do
      get "/admin/production_orders/pause"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /complete" do
    it "returns http success" do
      get "/admin/production_orders/complete"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /cancel" do
    it "returns http success" do
      get "/admin/production_orders/cancel"
      expect(response).to have_http_status(:success)
    end
  end
end
