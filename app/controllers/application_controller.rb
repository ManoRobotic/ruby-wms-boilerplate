class ApplicationController < ActionController::Base
  include Authorization

  before_action :set_locale
  before_action :configure_permitted_parameters, if: :devise_controller?
  allow_browser versions: :modern

  protected

  def current_user_or_admin
    current_user || current_admin
  end

  def user_signed_in_or_admin?
    user_signed_in? || admin_signed_in?
  end

  # Helper methods for views
  helper_method :can?, :cannot?, :current_user_or_admin

  # Método para determinar la página de inicio según el rol
  def after_sign_in_path_for(resource)
    if resource.is_a?(Admin)
      admin_root_path
    elsif resource.is_a?(User)
      case resource.role
      when "admin"
        admin_root_path
      when "supervisor"
        resource.warehouse ? admin_warehouse_path(resource.warehouse) : admin_warehouses_path
      when "picker"
        admin_tasks_path
      when "operador"
        admin_root_path
      else
        root_path
      end
    else
      root_path
    end
  end

  private

  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end

  def default_url_options
    { locale: I18n.locale }
  end

  def configure_permitted_parameters
    if resource_class == User
      devise_parameter_sanitizer.permit(:sign_up, keys: [ :name, :role, :warehouse_id ])
      devise_parameter_sanitizer.permit(:account_update, keys: [ :name, :warehouse_id ])
    end
  end
end
