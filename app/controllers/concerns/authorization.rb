module Authorization
  extend ActiveSupport::Concern

  class NotAuthorized < StandardError; end

  included do
    rescue_from Authorization::NotAuthorized, with: :handle_not_authorized
    before_action :authenticate_user_or_admin!, unless: :devise_controller?
    before_action :check_user_active, unless: :devise_controller?
  end

  protected

  def current_user_or_admin
    current_user || current_admin
  end

  def user_signed_in_or_admin?
    user_signed_in? || admin_signed_in?
  end

  def authenticate_user_or_admin!
    unless user_signed_in_or_admin?
      if request.format.json?
        render json: { error: "No autorizado" }, status: :unauthorized
      else
        redirect_to new_user_session_path, alert: "Debes iniciar sesión para continuar."
      end
    end
  end

  def check_user_active
    if current_user&.active == false
      sign_out current_user
      redirect_to new_user_session_path, alert: "Tu cuenta ha sido desactivada."
    end
  end

  def authorize!(action, resource = nil)
    user = current_user_or_admin

    # Si es admin (modelo Admin), tiene acceso completo
    if current_admin
      return true
    end

    # Si es user (modelo User), verificar permisos
    if current_user && !current_user.can?(action, resource)
      raise Authorization::NotAuthorized, "No tienes permisos para #{action}"
    end

    true
  end

  def can?(action, resource = nil)
    return true if current_admin
    current_user&.can?(action, resource) || false
  end

  def cannot?(action, resource = nil)
    !can?(action, resource)
  end

  # Verificar si el usuario puede acceder a un almacén específico
  def authorize_warehouse_access!(warehouse)
    return true if current_admin

    if current_user
      if current_user.warehouse_id.present? && current_user.warehouse_id != warehouse.id
        raise Authorization::NotAuthorized, "No tienes acceso a este almacén"
      end
    end

    true
  end

  private

  def handle_not_authorized(exception)
    Rails.logger.warn "Authorization failed: #{exception.message} for #{current_user_or_admin&.email}"

    if request.format.json?
      render json: { error: exception.message }, status: :forbidden
    else
      redirect_back fallback_location: root_path, alert: exception.message
    end
  end
end
