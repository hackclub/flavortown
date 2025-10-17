# app/controllers/admin/application_controller.rb
class Admin::AdminController < ApplicationController
def index
   @current_user =  current_user

end
  
 end  