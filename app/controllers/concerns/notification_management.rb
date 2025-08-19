module NotificationManagement
  extend ActiveSupport::Concern

  included do
    # Cache key helpers for notifications
    def notifications_cache_key(user_or_admin)
      "notifications_data:#{user_or_admin.class.name.downcase}:#{user_or_admin.id}:#{user_or_admin.updated_at}"
    end

    def current_user_notifications_cache_key
      user_or_admin = current_user || current_admin
      return nil unless user_or_admin
      notifications_cache_key(user_or_admin)
    end

    # Get cached notification data to avoid repeated queries
    def cached_notifications_data(user_or_admin)
      cache_key = notifications_cache_key(user_or_admin)
      
      Rails.cache.fetch(cache_key, expires_in: 2.minutes) do
        if user_or_admin.is_a?(Admin)
          admin_user = User.find_by(email: user_or_admin.email, role: 'admin')
          notifications_scope = admin_user&.notifications || Notification.none
        else
          notifications_scope = user_or_admin.notifications
        end

        # Single query to get recent notifications with count
        recent_notifications = notifications_scope
                               .select(:id, :title, :message, :notification_type, :action_url, :read_at, :created_at)
                               .order(created_at: :desc)
                               .limit(10)
                               .to_a

        unread_count = recent_notifications.count { |n| n.read_at.nil? }
        
        {
          recent_notifications: recent_notifications,
          unread_count: unread_count,
          has_notifications: recent_notifications.any?
        }
      end
    end

    # Expire notification cache when needed
    def expire_notifications_cache(user_or_admin)
      cache_key = notifications_cache_key(user_or_admin)
      Rails.cache.delete(cache_key)
    end

    # Helper to get current user for notifications
    def current_user_for_notifications
      current_user || current_admin
    end
  end
end