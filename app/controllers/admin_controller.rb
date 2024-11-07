class AdminController < ApplicationController
  layout "admin"
  before_action :authenticate_admin!

  def index
    puts "hola admin"
  end
end
