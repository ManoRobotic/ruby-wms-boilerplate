class Company < ApplicationRecord
  has_many :products
  has_many :categories
  has_many :production_orders
  has_many :warehouses
  has_many :admins

  # Validations

  # Printer model enum
  validates :printer_model, inclusion: { in: %w[zebra tsc], message: "must be either 'zebra' or 'tsc'"}, allow_nil: true

  # Serial device ID validation
  validates :serial_device_id, length: { maximum: 255 }, allow_blank: true

  # Set default printer model
  after_initialize :set_default_printer_model

  # Google Sheets Configuration
  def google_sheets_configured?
    google_sheets_enabled? && 
    google_credentials.present? && 
    sheet_id.present?
  end

  def google_credentials_json
    return nil unless google_credentials.present?
    JSON.parse(google_credentials) rescue nil
  end

  def set_google_credentials(credentials_hash)
    self.google_credentials = credentials_hash.to_json
  end

  # Validate Google credentials format
  def validate_google_credentials
    return true unless google_credentials.present?

    begin
      parsed = JSON.parse(google_credentials)
      required_keys = %w[type project_id private_key_id private_key client_email client_id auth_uri token_uri]
      required_keys.all? { |key| parsed.key?(key) }
    rescue JSON::ParserError
      false
    end
  end

  # Serial and printer configuration helpers
  def serial_configured?
    serial_port.present? && serial_baud_rate.present?;
  end

  def printer_configured?
    printer_port.present? && printer_baud_rate.present?
  end

  def scale_and_printer_configured?
    serial_configured? && printer_configured?
  end


  # Ensure serial device ID is set
  before_create :set_serial_device_id

  private

  def set_default_printer_model
    self.printer_model ||= 'zebra'
  end

  def set_serial_device_id
    self.serial_device_id ||= "device-serial-#{SecureRandom.uuid.gsub('-', '')}"
  end
end
