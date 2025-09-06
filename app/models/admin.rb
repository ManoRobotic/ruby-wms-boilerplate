class Admin < ApplicationRecord
  belongs_to :company, optional: true
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Fix for Rails 8 and Devise compatibility
  def self.serialize_from_session(key, salt = nil)
    record = find_by(id: key)
    return record unless salt
    record if record && record.authenticatable_salt == salt
  end

  # Display methods to match User model interface
  def display_name
    name.present? ? name : email
  end

  # Notification methods - Admins should have their own notifications
  # We'll use a virtual approach where Admin notifications are stored with a special admin user
  def notifications
    admin_user = User.find_by(email: self.email, role: 'admin')
    if admin_user
      admin_user.notifications
    else
      Notification.none
    end
  end

  def unread_notifications_count
    # Use a more efficient query for counting  
    notifications.where(read_at: nil).count
  end

  def recent_notifications(limit = 10)
    notifications.order(created_at: :desc).limit(limit)
  end

  # Delegate configuration methods to company
  delegate :google_sheets_enabled, :google_sheets_enabled?, to: :company, allow_nil: true
  delegate :sheet_id, to: :company, allow_nil: true
  delegate :google_credentials, to: :company, allow_nil: true
  delegate :serial_port, to: :company, allow_nil: true
  delegate :serial_baud_rate, to: :company, allow_nil: true
  delegate :serial_parity, to: :company, allow_nil: true
  delegate :serial_stop_bits, to: :company, allow_nil: true
  delegate :serial_data_bits, to: :company, allow_nil: true
  delegate :printer_port, to: :company, allow_nil: true
  delegate :printer_baud_rate, to: :company, allow_nil: true
  delegate :printer_parity, to: :company, allow_nil: true
  delegate :printer_stop_bits, to: :company, allow_nil: true
  delegate :printer_data_bits, to: :company, allow_nil: true
  delegate :last_sync_at, to: :company, allow_nil: true
  delegate :last_sync_checksum, to: :company, allow_nil: true
  delegate :total_orders_synced, to: :company, allow_nil: true

  # Google Sheets Configuration
  def google_sheets_configured?
    company&.google_sheets_configured? || false
  end

  def google_credentials_json
    company&.google_credentials_json
  end

  def set_google_credentials(credentials_hash)
    return unless company
    company.set_google_credentials(credentials_hash)
    company.save
  end

  # Validate Google credentials format
  def validate_google_credentials
    company&.validate_google_credentials || true
  end

  # Super Admin Role methods
  SUPER_ADMIN_ROLES = %w[rzavala flexiempaques global].freeze

  validates :super_admin_role, inclusion: { in: SUPER_ADMIN_ROLES, allow_blank: true }

  def super_admin?
    super_admin_role == 'global'
  end

  def rzavala?
    super_admin_role == 'rzavala'
  end

  def flexiempaques?
    super_admin_role == 'flexiempaques'
  end

  # Scope for super admins
  scope :super_admins, -> { where.not(super_admin_role: nil) }
  scope :by_super_admin_role, ->(role) { where(super_admin_role: role) }
  scope :rzavala, -> { where(super_admin_role: 'rzavala') }
  scope :flexiempaques, -> { where(super_admin_role: 'flexiempaques') }
  scope :by_company, ->(company) { where(company: company) }

  # Data isolation by super admin role
  def accessible_production_orders
    return ProductionOrder.all unless super_admin?
    ProductionOrder.joins(:admin).where(admins: { super_admin_role: super_admin_role })
  end

  def accessible_admins
    return Admin.all unless super_admin?
    Admin.where(super_admin_role: super_admin_role)
  end

  # Serial and printer configuration helpers
  def serial_configured?
    company&.serial_configured? || false
  end

  def printer_configured?
    company&.printer_configured? || false
  end

  def scale_and_printer_configured?
    company&.scale_and_printer_configured? || false
  end
end
