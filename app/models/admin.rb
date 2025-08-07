class Admin < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :notifications, foreign_key: :user_id, dependent: :destroy

  # Fix for Rails 8 and Devise compatibility
  def self.serialize_from_session(key, salt = nil)
    record = find_by(id: key)
    return record unless salt
    record if record && record.authenticatable_salt == salt
  end

  # Display methods to match User model interface
  def display_name
    email
  end

  # Notification methods to match User model interface
  def unread_notifications_count
    notifications.unread.count
  end

  def recent_notifications(limit = 10)
    notifications.recent.limit(limit)
  end
end
