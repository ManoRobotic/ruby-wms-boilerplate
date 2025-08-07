class Notification < ApplicationRecord
  belongs_to :user

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :message, presence: true, length: { maximum: 1000 }
  validates :notification_type, presence: true, inclusion: { in: %w[task_assigned task_status_changed order_updated inventory_alert system admin_alert] }

  # Serialized data
  serialize :data, coder: JSON

  # Scopes
  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(notification_type: type) }

  # Instance methods
  def read?
    read_at.present?
  end

  def unread?
    !read?
  end

  def mark_as_read!
    return if read?
    update!(read_at: Time.current)
  end

  def mark_as_unread!
    return if unread?
    update!(read_at: nil)
  end

  def time_ago
    return "Just now" if created_at > 1.minute.ago
    return "#{time_ago_in_words(created_at)} ago" if created_at > 1.day.ago
    created_at.strftime("%b %d at %I:%M %p")
  end

  # Class methods
  def self.create_task_assignment(user:, task:)
    create!(
      user: user,
      notification_type: "task_assigned",
      title: "Nueva tarea asignada",
      message: "Se te ha asignado la tarea: #{task.display_name}",
      action_url: "/admin/tasks/#{task.id}",
      data: {
        task_id: task.id,
        task_type: task.task_type,
        priority: task.priority,
        warehouse_id: task.warehouse_id
      }
    )
  end

  def self.create_task_status_change(user:, task:, old_status:, new_status:)
    create!(
      user: user,
      notification_type: "task_status_changed",
      title: "Estado de tarea actualizado",
      message: "La tarea #{task.display_name} cambió de #{old_status} a #{new_status}",
      action_url: "/admin/tasks/#{task.id}",
      data: {
        task_id: task.id,
        old_status: old_status,
        new_status: new_status,
        warehouse_id: task.warehouse_id
      }
    )
  end

  def self.create_order_alert(admin:, order:, message:)
    create!(
      user: admin,
      notification_type: "order_updated",
      title: "Nueva orden recibida",
      message: message,
      action_url: "/admin/orders/#{order.id}",
      data: {
        order_id: order.id,
        total: order.total
      }
    )
  end

  def self.create_system_alert(admin:, title:, message:, action_url: nil)
    create!(
      user: admin,
      notification_type: "system",
      title: title,
      message: message,
      action_url: action_url,
      data: {}
    )
  end

  def self.create_inventory_alert(admin:, product:, warehouse:, message:)
    create!(
      user: admin,
      notification_type: "inventory_alert",
      title: "Alerta de inventario",
      message: message,
      action_url: "/admin/inventory_transactions",
      data: {
        product_id: product.id,
        warehouse_id: warehouse.id,
        product_name: product.name
      }
    )
  end

  def self.mark_all_as_read_for_user(user)
    where(user: user, read_at: nil).update_all(read_at: Time.current)
  end

  private

  def time_ago_in_words(time)
    ActionController::Base.helpers.time_ago_in_words(time)
  end
end
