module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user_or_admin

    def connect
      self.current_user_or_admin = find_verified_user_or_admin
    end

    private

    def find_verified_user_or_admin
      Rails.logger.info "🔍 Starting user/admin verification for ActionCable"
      
      # 1. Try to find a logged-in user or admin via Devise/Warden (for browsers)
      verified_user = env['warden'].user(:user) || env['warden'].user(:admin)
      if verified_user
        Rails.logger.info "  ✅ Verified browser session for: #{verified_user.email}"
        return verified_user
      end

      # 2. If no cookie session, try to authenticate via device token in URL params
      token = request.params[:token]
      if token
        verified_company = Company.find_by(serial_auth_token: token)
        if verified_company
          Rails.logger.info "  ✅ Verified device connection for Company: #{verified_company.name}"
          return verified_company # Identify the connection by the company object
        else
          Rails.logger.warn "  ❌ Unauthorized device token received: #{token}"
          reject_unauthorized_connection
        end
      else
        # 3. If no cookie and no token, reject.
        Rails.logger.warn "  ❌ Unauthorized connection rejected (no session or token)"
        reject_unauthorized_connection
      end
    end

    
  end
end