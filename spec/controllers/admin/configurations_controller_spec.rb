require 'rails_helper'

RSpec.describe Admin::ConfigurationsController, type: :controller do
  let(:company) { create(:company) }
  let(:admin) { create(:admin, email: "test@example.com", password: "password123", password_confirmation: "password123", company: company) }

  before do
    sign_in admin
  end

  describe "GET #show" do
    it "returns http success" do
      get :show

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:show)
      expect(assigns(:admin)).to eq(admin)
      expect(assigns(:company)).to eq(company)
    end

    it "ensures company has serial_device_id" do
      company.update!(serial_device_id: nil)

      get :show

      expect(assigns(:company).serial_device_id).not_to be_blank
    end
  end

  describe "PATCH #handle_configuration_update" do
    context "with valid parameters" do
      it "updates the company configuration" do
        patch :handle_configuration_update, params: { company: { name: "Updated Company Name", printer_model: "epson" } }

        expect(response).to redirect_to(admin_configurations_path)
        expect(flash[:notice]).to eq("Configuración actualizada exitosamente.")
        expect(company.reload.name).to eq("Updated Company Name")
        expect(company.reload.printer_model).to eq("epson")
      end
    end

    context "with invalid parameters" do
      it "renders the show template with errors" do
        # Force an error by trying to update with invalid data
        allow(company).to receive(:update).and_return(false)
        allow(company).to receive(:errors).and_return(double(full_messages: ["Name can't be blank"]))

        patch :handle_configuration_update, params: { company: { name: "" } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:show)
      end
    end

    context "when admin doesn't have associated company" do
      let(:admin_without_company) { create(:admin, email: "test2@example.com", password: "password123", password_confirmation: "password123") }

      before do
        sign_in admin_without_company
        allow(admin_without_company).to receive(:company).and_return(nil)
      end

      it "redirects with an alert" do
        patch :handle_configuration_update, params: { company: { name: "New Name" } }

        expect(response).to redirect_to(admin_configurations_path)
        expect(flash[:alert]).to eq("No se puede actualizar la configuración: el administrador no está asociado a una empresa.")
      end
    end
  end

  describe "GET #saved_config" do
    it "returns configuration data as JSON" do
      company.update!(serial_port: "/dev/ttyUSB0", printer_port: "LPT1", 
                     serial_baud_rate: 9600, printer_baud_rate: 19200)

      get :saved_config

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/json; charset=utf-8")

      json_response = JSON.parse(response.body)
      expect(json_response["serial_port"]).to eq("/dev/ttyUSB0")
      expect(json_response["printer_port"]).to eq("LPT1")
      expect(json_response["serial_baud_rate"]).to eq(9600)
      expect(json_response["printer_baud_rate"]).to eq(19200)
    end

    it "returns empty JSON when admin doesn't have a company" do
      allow(admin).to receive(:company).and_return(nil)

      get :saved_config

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("{}")
    end
  end

  describe "GET #test_connection" do
    before do
      allow(admin).to receive(:google_sheets_configured?).and_return(true)
    end

    it "returns success when Google Sheets is configured correctly" do
      # Mock the Google Sheets service
      service_double = double(AdminGoogleSheetsService)
      worksheet_double = double(title: "Test Sheet", num_rows: 10)
      allow(service_double).to receive(:find_opro_worksheet).and_return(worksheet_double)
      allow(AdminGoogleSheetsService).to receive(:new).with(admin).and_return(service_double)

      get :test_connection

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/json; charset=utf-8")

      json_response = JSON.parse(response.body)
      expect(json_response["success"]).to be true
      expect(json_response["message"]).to include("Conexión exitosa")
      expect(json_response["worksheet_title"]).to eq("Test Sheet")
      expect(json_response["num_rows"]).to eq(10)
    end

    it "returns error when Google Sheets is not configured" do
      allow(admin).to receive(:google_sheets_configured?).and_return(false)

      get :test_connection

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response["success"]).to be false
    end
  end

  describe "GET #check_changes" do
    before do
      allow(admin).to receive(:google_sheets_configured?).and_return(true)
    end

    it "returns success when changes are checked successfully" do
      # Mock the Google Sheets service
      service_double = double(IncrementalGoogleSheetsService)
      result_hash = {
        has_changes: true,
        message: "Changes detected",
        details: "Some details",
        current_rows: 50,
        last_sync: Time.current
      }
      allow(service_double).to receive(:check_for_changes).and_return(result_hash)
      allow(IncrementalGoogleSheetsService).to receive(:new).with(admin).and_return(service_double)

      get :check_changes

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/json; charset=utf-8")

      json_response = JSON.parse(response.body)
      expect(json_response["success"]).to be true
      expect(json_response["has_changes"]).to be true
    end

    it "returns error when Google Sheets is not configured" do
      allow(admin).to receive(:google_sheets_configured?).and_return(false)

      get :check_changes

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response["success"]).to be false
    end
  end

  describe "POST #auto_save" do
    it "updates company configuration with valid parameters" do
      post :auto_save, params: { 
        company: { 
          serial_port: "/dev/ttyUSB1", 
          printer_port: "LPT2", 
          printer_model: "epson" 
        } 
      }

      expect(response).to redirect_to(admin_configurations_path)
      expect(flash[:notice]).to eq("Configuración guardada automáticamente.")
      expect(company.reload.serial_port).to eq("/dev/ttyUSB1")
      expect(company.reload.printer_port).to eq("LPT2")
      expect(company.reload.printer_model).to eq("epson")
    end

    it "returns JSON response for JSON requests" do
      post :auto_save, params: { 
        company: { 
          serial_port: "/dev/ttyUSB2", 
          printer_model: "zebra" 
        } 
      }, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/json; charset=utf-8")

      json_response = JSON.parse(response.body)
      expect(json_response["success"]).to be true
      expect(json_response["message"]).to eq("Configuración guardada automáticamente.")
    end

    it "returns error for invalid parameters" do
      # Force an update error
      allow(company).to receive(:update).and_return(false)
      allow(company).to receive(:errors).and_return(double(full_messages: ["Serial port is invalid"]))

      post :auto_save, params: { company: { serial_port: "invalid_port" } }, format: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json_response = JSON.parse(response.body)
      expect(json_response["success"]).to be false
    end
  end
end