# app/controllers/admin/application_controller.rb
module Admin
   class ApplicationController < ::ApplicationController
     # Shared admin logic here
     def index
      @current_user =  current_user
      @is_admin = current_user.roles.exists?(name: "admin")
     end
   end
end
