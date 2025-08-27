class Admin < ApplicationRecord
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

  # Google Sheets Configuration
  def google_sheets_configured?
    google_sheets_enabled? && 
    google_credentials.present? && 
    sheet_id.present?
    # Ya no requerimos worksheet_gid porque se auto-detecta
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

  # Data isolation by super admin role
  def accessible_production_orders
    return ProductionOrder.all unless super_admin?
    ProductionOrder.joins(:admin).where(admins: { super_admin_role: super_admin_role })
  end

  def accessible_admins
    return Admin.all unless super_admin?
    Admin.where(super_admin_role: super_admin_role)
  end
end
