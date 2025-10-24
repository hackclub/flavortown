class LandingController < ApplicationController
  def index
   @current_user =  current_user
   @is_admin = current_user&.roles&.exists?(name: "admin") || false
  end
end
