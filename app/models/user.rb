class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  belongs_to :warehouse, optional: true
  has_many :tasks, foreign_key: :admin_id, dependent: :nullify
  has_many :pick_lists, foreign_key: :admin_id, dependent: :nullify
  has_many :inventory_transactions, foreign_key: :admin_id, dependent: :nullify
  has_many :waves, foreign_key: :admin_id, dependent: :nullify
  has_many :notifications, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: %w[admin user supervisor picker] }
  validates :warehouse_id, presence: true, unless: :admin?

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_role, ->(role) { where(role: role) }
  scope :by_warehouse, ->(warehouse) { where(warehouse: warehouse) }
  scope :admins, -> { where(role: "admin") }
  scope :users, -> { where(role: "user") }
  scope :supervisors, -> { where(role: "supervisor") }
  scope :pickers, -> { where(role: "picker") }

  # Serialized permissions
  serialize :permissions, coder: JSON

  # Role methods
  def admin?
    role == "admin"
  end

  def user?
    role == "user"
  end

  def supervisor?
    role == "supervisor"
  end

  def picker?
    role == "picker"
  end

  def warehouse_admin?
    supervisor? || admin?
  end

  # Permission system
  def can?(action, resource = nil)
    case role
    when "admin"
      true # Los users con rol admin tienen acceso completo
    when "supervisor"
      supervisor_permissions(action, resource)
    when "picker"
      picker_permissions(action, resource)
    when "user"
      user_permissions(action, resource)
    else
      false
    end
  end

  def cannot?(action, resource = nil)
    !can?(action, resource)
  end

  # Display methods
  def display_name
    name.present? ? name : email
  end

  def role_display
    I18n.t("users.roles.#{role}", default: role.humanize)
  end

  # Notification methods
  def unread_notifications_count
    notifications.unread.count
  end

  def recent_notifications(limit = 10)
    notifications.recent.limit(limit)
  end

  private

  def supervisor_permissions(action, resource)
    warehouse_permissions = %w[
      read_admin_dashboard read_warehouse read_zones read_locations read_inventory
      create_zones create_locations create_tasks create_pick_lists
      manage_inventory manage_receipts manage_shipments manage_waves
      read_orders read_products read_reports manage_users manage_warehouses
    ]

    case action.to_s
    when *warehouse_permissions
      true
    when "manage_admins", "manage_categories", "manage_products"
      false
    else
      false
    end
  end

  def picker_permissions(action, resource)
    picker_permissions = %w[
      read_tasks read_pick_lists update_pick_lists
      read_locations read_inventory update_inventory_transactions
      read_orders
    ]

    case action.to_s
    when *picker_permissions
      true
    else
      false
    end
  end

  def user_permissions(action, resource)
    user_permissions = %w[
      read_orders read_products read_inventory read_locations
    ]

    case action.to_s
    when *user_permissions
      true
    else
      false
    end
  end
end
