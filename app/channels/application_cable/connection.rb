module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user_or_admin

    def connect
      self.current_user_or_admin = find_verified_user_or_admin
    end

    private

    def find_verified_user_or_admin
      Rails.logger.info "🔍 Starting user/admin verification for ActionCable"
      
      if (current_user = env['warden'].user(:user))
        Rails.logger.info "  ✅ Verified User: #{current_user.email}"
        current_user
      elsif (current_admin = env['warden'].user(:admin))
        Rails.logger.info "  ✅ Verified Admin: #{current_admin.email}"
        current_admin
      else
        Rails.logger.warn "  ❌ Unauthorized connection rejected"
        reject_unauthorized_connection
      end
    end

    
  end
end