require 'rails_helper'
require 'webmock/rspec'

RSpec.describe SerialCommunicationService, type: :service do
  let(:company) { double('Company', serial_service_url: 'http://test-serial.local:5000') }
  let(:base_url) { 'http://test-serial.local:5000' }

  before do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  describe '.status' do
    it 'fetches status with ngrok skip headers' do
      stub_request(:get, "#{base_url}/health")
        .with(headers: { 'ngrok-skip-browser-warning' => 'true' })
        .to_return(status: 200, body: { status: 'healthy', scale_connected: true, printer_connected: false }.to_json)

      result = described_class.status(company: company)
      
      expect(result[:status]).to eq('healthy')
      expect(result[:scale_connected]).to be true
      expect(result[:printer_connected]).to be false
    end

    it 'handles connection errors gracefully' do
      stub_request(:get, "#{base_url}/health").to_raise(StandardError.new("Connection refused"))

      result = described_class.status(company: company)
      expect(result[:status]).to eq('error')
      expect(result[:message]).to eq('Connection refused')
    end
  end

  describe '.get_weight_with_timeout' do
    it 'sends request with ngrok skip headers' do
      stub_request(:get, "#{base_url}/scale/latest")
        .with(headers: { 'ngrok-skip-browser-warning' => 'true' })
        .to_return(status: 200, body: { readings: [{ status: 'success', weight: '10.5kg' }] }.to_json)

      result = described_class.get_weight_with_timeout(timeout_seconds: 5, company: company)
      expect(result['weight']).to eq('10.5kg')
    end
  end

  describe '.print_label' do
    it 'posts with ngrok skip headers' do
      payload = { content: 'Test', ancho_mm: 80, alto_mm: 50 }
      stub_request(:post, "#{base_url}/printer/print")
        .with(
          headers: { 'ngrok-skip-browser-warning' => 'true' },
          body: payload.to_json
        )
        .to_return(status: 200, body: { status: 'success' }.to_json)

      result = described_class.print_label(payload[:content], ancho_mm: 80, alto_mm: 50, company: company)
      expect(result).to be true
    end
  end
end
