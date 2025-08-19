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
end
