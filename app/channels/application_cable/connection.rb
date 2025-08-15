module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user_or_admin

    def connect
      self.current_user_or_admin = find_verified_user_or_admin
    end

    private

    def find_verified_user_or_admin
      # Try to find current user via Devise warden session
      if (user_id = session.dig('warden.user.user.key', 0, 0))
        user = User.find_by(id: user_id)
        return user if user
      end
      
      # Try to find current admin via Devise warden session
      if (admin_id = session.dig('warden.user.admin.key', 0, 0))
        admin = Admin.find_by(id: admin_id)
        return admin if admin
      end
      
      # Fallback to old format
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