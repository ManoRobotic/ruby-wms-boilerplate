# frozen_string_literal: true

class Admin::SessionsController < Devise::SessionsController
  layout "application"

  protected

  # Mantener flash para que persista hasta la página del admin
  def after_sign_in_path_for(resource)
    flash.keep if flash.any?
    stored_location_for(resource) || admin_root_path
  end
end
