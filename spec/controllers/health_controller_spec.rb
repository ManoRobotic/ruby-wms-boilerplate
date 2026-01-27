require 'rails_helper'

RSpec.describe HealthController, type: :controller do
  let(:admin) { create(:admin, email: "test@example.com", password: "password123", password_confirmation: "password123") }

  before do
    sign_in admin
  end

  describe "GET #check" do
    before do
      # Mock the health check methods to return success status in tests
      allow_any_instance_of(HealthController).to receive(:database_status).and_return({
        status: "ok",
        response_time_ms: 10.0,
        pool_size: 5,
        active_connections: 2
      })
      allow_any_instance_of(HealthController).to receive(:cache_status).and_return({
        status: "ok",
        response_time_ms: 5.0
      })
      allow_any_instance_of(HealthController).to receive(:storage_status).and_return({
        status: "ok",
        response_time_ms: 0
      })
    end

    it "returns health status with ok status" do
      get :check

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/json; charset=utf-8")

      json_response = JSON.parse(response.body)
      expect(json_response).to have_key("status")
      expect(json_response["status"]).to eq("ok")
      expect(json_response).to have_key("timestamp")
      expect(json_response).to have_key("version")
      expect(json_response).to have_key("environment")
      expect(json_response).to have_key("checks")
      expect(json_response["checks"]).to have_key("database")
      expect(json_response["checks"]).to have_key("cache")
      expect(json_response["checks"]).to have_key("storage")
    end

    it "returns correct database status" do
      get :check

      json_response = JSON.parse(response.body)
      database_status = json_response["checks"]["database"]
      expect(database_status["status"]).to eq("ok")
      expect(database_status).to have_key("response_time_ms")
      expect(database_status).to have_key("pool_size")
      expect(database_status).to have_key("active_connections")
    end

    it "returns correct cache status" do
      get :check

      json_response = JSON.parse(response.body)
      cache_status = json_response["checks"]["cache"]
      expect(cache_status["status"]).to eq("ok")
      expect(cache_status).to have_key("response_time_ms")
    end

    it "returns correct storage status" do
      get :check

      json_response = JSON.parse(response.body)
      storage_status = json_response["checks"]["storage"]
      expect(storage_status["status"]).to eq("ok")
      expect(storage_status).to have_key("response_time_ms")
    end
  end

  describe "GET #liveness" do
    it "returns liveness status with ok status" do
      get :liveness

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/json; charset=utf-8")

      json_response = JSON.parse(response.body)
      expect(json_response).to have_key("status")
      expect(json_response["status"]).to eq("ok")
      expect(json_response).to have_key("timestamp")
    end
  end

  describe "GET #readiness" do
    before do
      # Mock the readiness methods to return true by default in tests
      allow_any_instance_of(HealthController).to receive(:database_ready?).and_return(true)
      allow_any_instance_of(HealthController).to receive(:cache_ready?).and_return(true)
    end

    it "returns readiness status with ok status when ready" do
      get :readiness

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/json; charset=utf-8")

      json_response = JSON.parse(response.body)
      expect(json_response).to have_key("status")
      expect(json_response["status"]).to eq("ready")
      expect(json_response).to have_key("timestamp")
    end

    it "returns not ready status when not ready" do
      # Mock the database_ready? method to return false
      allow_any_instance_of(HealthController).to receive(:database_ready?).and_return(false)

      get :readiness

      expect(response).to have_http_status(:service_unavailable)
      expect(response.content_type).to eq("application/json; charset=utf-8")

      json_response = JSON.parse(response.body)
      expect(json_response).to have_key("status")
      expect(json_response["status"]).to eq("not_ready")
      expect(json_response).to have_key("timestamp")
    end
  end
end