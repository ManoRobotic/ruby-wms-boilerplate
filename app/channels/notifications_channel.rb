class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    Rails.logger.info "🔔 NotificationsChannel subscription attempt"
    Rails.logger.info "📋 Current user/admin: #{current_user_or_admin.inspect}"
    
    if current_user_or_admin.is_a?(User)
      channel_name = "notifications_#{current_user_or_admin.id}"
      stream_from channel_name
      Rails.logger.info "👤 User subscribed to channel: #{channel_name}"
    elsif current_user_or_admin.is_a?(Admin)
      # For admins, find or create the corresponding user
      admin_user = User.find_by(email: current_user_or_admin.email, role: 'admin')
      if admin_user
        channel_name = "notifications_#{admin_user.id}"
        stream_from channel_name
        Rails.logger.info "👨‍💼 Admin subscribed to channel: #{channel_name}"
      else
        Rails.logger.warn "⚠️ Admin has no corresponding user: #{current_user_or_admin.email}"
      end
    else
      Rails.logger.error "❌ No valid user or admin found for subscription"
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end