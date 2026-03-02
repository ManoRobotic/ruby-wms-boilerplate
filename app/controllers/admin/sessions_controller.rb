# frozen_string_literal: true

class Admin::SessionsController < Devise::SessionsController
  layout "application"

  protected

  # Mantener el flash para que persista después del redirect al admin
  def after_sign_in_path_for(resource)
    flash.keep[:notice] if flash[:notice]
    stored_location_for(resource) || admin_root_path
  end
end
