module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user_or_admin

    def connect
      self.current_user_or_admin = find_verified_user_or_admin
    end

    private

    def find_verified_user_or_admin
      # Try to find current user via session
      if (user = User.find_by(id: session[:user_id]))
        user
      elsif (admin = Admin.find_by(id: session[:admin_id]))
        admin
      else
        reject_unauthorized_connection
      end
    end

    def session
      @session ||= cookies.encrypted[:_ruby_wms_boilerplate_session] || {}
    end
  end
end