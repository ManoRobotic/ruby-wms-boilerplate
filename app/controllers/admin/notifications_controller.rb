class Admin::NotificationsController < ApplicationController
  before_action :authenticate_admin_or_user!
  before_action :set_notification, only: [:show, :mark_read, :destroy]

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
    
    respond_to do |format|
      format.json { render json: { status: 'success' } }
      format.html { redirect_back(fallback_location: admin_notifications_path) }
    end
  end

  def mark_all_read
    current_user_notifications.unread.update_all(read_at: Time.current)
    
    respond_to do |format|
      format.json { render json: { status: 'success' } }
      format.html { redirect_back(fallback_location: admin_notifications_path) }
    end
  end

  def destroy
    @notification.destroy
    
    respond_to do |format|
      format.json { render json: { status: 'success' } }
      format.html { redirect_back(fallback_location: admin_notifications_path) }
    end
  end

  private

  def set_notification
    @notification = current_user_notifications.find(params[:id])
  end

  def current_user_notifications
    if current_user
      current_user.notifications
    elsif current_admin
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