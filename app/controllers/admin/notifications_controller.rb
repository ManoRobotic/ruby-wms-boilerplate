class Admin::NotificationsController < ApplicationController
  include NotificationManagement
  
  before_action :authenticate_admin_or_user!
  before_action :set_notification, only: [ :show, :mark_read, :destroy ]

  def index
    @notifications = current_user_notifications.recent.page(params[:page]).per(20)
  end

  def show
    @notification.mark_as_read! if @notification.unread?

    if @notification.action_url.present?
      redirect_to @notification.action_url
    else
      redirect_to admin_notifications_path
    end
  end

  def mark_read
    @notification.mark_as_read!
    
    # Expire cache after marking as read
    expire_notifications_cache(current_user_for_notifications) if current_user_for_notifications

    respond_to do |format|
      format.json do
        render json: { status: "success" } 
      end
      format.html do
        redirect_back(fallback_location: admin_notifications_path) 
      end
    end
  end

  def mark_all_read
    current_user_notifications.unread.update_all(read_at: Time.current)
    
    # Expire cache after marking all as read
    expire_notifications_cache(current_user_for_notifications) if current_user_for_notifications

    respond_to do |format|
      format.json { render json: { status: "success" } }
      format.html { redirect_back(fallback_location: admin_notifications_path) }
    end
  end

  def poll
    last_poll = begin
      if params[:last_poll].present? && params[:last_poll] != 'undefined'
        params[:last_poll].to_datetime
      else
        1.hour.ago
      end
    rescue ArgumentError, Date::Error
      1.hour.ago
    end
    
    # Use cached data when possible
    user_or_admin = current_user_for_notifications
    if user_or_admin
      cached_data = cached_notifications_data(user_or_admin)
      recent_notifications = cached_data[:recent_notifications]
      
      # Filter only new notifications since last poll
      new_notifications = recent_notifications.select { |n| n.created_at > last_poll }
      
      notifications_data = new_notifications.map do |notification|
        {
          id: notification.id,
          title: notification.title,
          message: notification.message,
          notification_type: notification.notification_type,
          created_at: notification.created_at.iso8601,
          read: notification.read?,
          action_url: notification.action_url
        }
      end

      render json: {
        notifications: notifications_data,
        unread_count: cached_data[:unread_count],
        last_poll: Time.current.iso8601
      }
    else
      render json: {
        notifications: [],
        unread_count: 0,
        last_poll: Time.current.iso8601
      }
    end
  end

  def poll_immediate
    # Check for immediate notifications from cache
    last_check = params[:last_check]&.to_datetime || 5.seconds.ago
    
    immediate_notifications = []
    
    # Simple approach: check recent cache keys
    (0..30).each do |i|
      timestamp = (Time.current - i.seconds).to_i
      key = "new_notification_#{timestamp}"
      notification_data = Rails.cache.read(key)
      
      if notification_data && notification_data[:created_at].to_datetime > last_check
        immediate_notifications << notification_data
      end
    end

    render json: {
      immediate_notifications: immediate_notifications,
      last_check: Time.current.iso8601
    }
  end

  def destroy
    @notification.destroy

    respond_to do |format|
      format.json { render json: { status: "success" } }
      format.html { redirect_back(fallback_location: admin_notifications_path) }
    end
  end

  private

  def set_notification
    
    begin
      @notification = current_user_notifications.find(params[:id])
    rescue => e
      Rails.logger.error "❌ Error finding notification: #{e.message}"
      raise e
    end
  end

  def current_user_notifications
    if current_user
      current_user.notifications
    elsif current_admin
      # For Admins, show only their own notifications via the admin User record
      current_admin.notifications
    else
      Notification.none
    end
  end

  def authenticate_admin_or_user!
    unless current_user || current_admin
      redirect_to new_admin_session_path
    end
  end
end
