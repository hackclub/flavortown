# app/controllers/admin/application_controller.rb
module Admin
   class ApplicationController < ::ApplicationController
    include Pundit
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized  
     # Shared admin logic here
     def index
      @current_user =  current_user
      @is_admin = current_user.roles.exists?(name: "admin")
     end
     private

     def user_not_authorized
       flash[:alert] = "You are not authorized to perform this action."
       redirect_to(request.referrer || root_path)
     end  
   end
end
