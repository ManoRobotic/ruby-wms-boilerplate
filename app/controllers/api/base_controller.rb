# frozen_string_literal: true

class Api::BaseController < ActionController::API
  before_action :authenticate_company!
  
  attr_reader :current_company

  private

  def authenticate_company!
    token = request.headers['X-Company-Token'] || params[:company_token]
    
    @current_company = Company.find_by(serial_auth_token: token)
    
    if @current_company.nil?
      render json: { error: 'Unauthorized: Invalid company token' }, status: :unauthorized
    end
  end
end
