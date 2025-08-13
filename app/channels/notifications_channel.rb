class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    if current_user_or_admin.is_a?(User)
      stream_from "notifications_#{current_user_or_admin.id}"
    elsif current_user_or_admin.is_a?(Admin)
      # For admins, find or create the corresponding user
      admin_user = User.find_by(email: current_user_or_admin.email, role: 'admin')
      if admin_user
        stream_from "notifications_#{admin_user.id}"
      end
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end