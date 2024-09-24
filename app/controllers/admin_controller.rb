class AdminController < ApplicationController
    before_action :authenticate_admin!

    def index
        puts 'hola admin'
    end
end