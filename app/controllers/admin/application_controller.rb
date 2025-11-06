# app/controllers/admin/application_controller.rb
module Admin
  class ApplicationController < ::ApplicationController
    include Pundit::Authorization

    layout "admin"

    # Rescue all Pundit authorization errors
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

    # Optional before_action to enforce admin/fraud dept on all admin controllers
    before_action :authenticate_admin, unless: :mission_control_jobs?

    # Shared admin dashboard logic
    def index
      # Authorize access to Users page in AdminPolicy
      # authorize :admin, :users?
    end

    private

    # Use this to protect all admin endpoints
    def authenticate_admin
      authorize :admin, :access_admin_endpoints?  # calls AdminPolicy#access_admin_endpoints?
    end

    def mission_control_jobs?
      request.path.start_with?("/admin/jobs")
    end

    # Handles unauthorized access
    def user_not_authorized
      flash[:alert] = "You are not authorized to perform this action."
      redirect_to(request.referrer || root_path)
    end
  end
end
