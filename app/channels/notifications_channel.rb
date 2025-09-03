class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    if current_user_or_admin&.company
      stream_from "notifications:#{current_user_or_admin.company.to_gid_param}"
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end