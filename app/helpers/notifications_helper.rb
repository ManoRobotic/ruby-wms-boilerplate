module NotificationsHelper
  # Memoized notification data structure to avoid multiple database queries
  class NotificationData
    attr_reader :unread_count, :recent_notifications, :has_notifications

    def initialize(user_or_admin)
      @user_or_admin = user_or_admin
      @notifications_scope = get_notifications_scope
      load_notification_data
    end

    private

    def get_notifications_scope
      if @user_or_admin.is_a?(Admin)
        admin_user = User.find_by(email: @user_or_admin.email, role: 'admin')
        admin_user&.notifications || Notification.none
      elsif @user_or_admin.is_a?(User)
        @user_or_admin.notifications
      else
        Notification.none
      end
    end

    def load_notification_data
      # Get recent notifications for display (limited to 10 for performance)
      @recent_notifications = @notifications_scope
                              .select(:id, :title, :message, :notification_type, :action_url, :read_at, :created_at)
                              .recent
                              .limit(10)
                              .to_a

      # Get accurate unread count (not limited to 10)
      @unread_count = @notifications_scope.unread.count
      @has_notifications = @recent_notifications.any?
    end
  end

  # Get optimized notification data for current user/admin
  def current_user_notifications_data
    @current_user_notifications_data ||= begin
      user_or_admin = current_user || current_admin
      if user_or_admin
        # Try to use cached data from controller if available
        if respond_to?(:cached_notifications_data)
          cached_data = cached_notifications_data(user_or_admin)
          OpenStruct.new(cached_data)
        else
          NotificationData.new(user_or_admin)
        end
      else
        nil
      end
    end
  end

  # Get the display name for the current user or admin
  def current_user_display_name
    @current_user_display_name ||= begin
      user_or_admin = current_user || current_admin
      user_or_admin&.display_name || user_or_admin&.email || "Usuario"
    end
  end

  def current_user_display_email
    @current_user_display_email ||= begin
      user_or_admin = current_user || current_admin
      user_or_admin&.email
    end
  end

  # Get the first letter for avatar
  def current_user_avatar_letter
    @current_user_avatar_letter ||= begin
      user_or_admin = current_user || current_admin
      (user_or_admin&.display_name&.first || user_or_admin&.email&.first || "?").upcase
    end
  end

  # Get role display for current user
  def current_user_role_display
    @current_user_role_display ||= begin
      if current_user
        current_user.role_display
      elsif current_admin
        "Administrador"
      else
        "Usuario"
      end
    end
  end

  # Icon mapping for notification types
  def notification_icon_class(notification_type)
    case notification_type
    when 'task_assigned'
      'fa-solid fa-tasks w-5 h-5 text-blue-600'
    when 'task_status_changed'
      'fa-solid fa-sync-alt w-5 h-5 text-green-600'
    when 'order_updated'
      'fa-solid fa-shopping-cart w-5 h-5 text-orange-600'
    when 'inventory_alert'
      'fa-solid fa-exclamation-triangle w-5 h-5 text-yellow-600'
    when 'production_order_created'
      'fa-solid fa-industry w-5 h-5 text-blue-600'
    when 'system'
      'fa-solid fa-cog w-5 h-5 text-purple-600'
    else
      'fa-solid fa-info-circle w-5 h-5 text-gray-600'
    end
  end

  # Format time ago for notifications
  def notification_time_ago(created_at)
    return "Justo ahora" if created_at > 1.minute.ago
    return "#{time_ago_in_words(created_at)} atrás" if created_at > 1.day.ago
    created_at.strftime("%b %d a las %I:%M %p")
  end
end