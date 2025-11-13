# app/controllers/admin/application_controller.rb
module Admin
  class ApplicationController < ::ApplicationController
    include Pundit::Authorization

    layout "admin"

    # Rescue all Pundit authorization errors
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

    # Optional before_action to enforce admin/fraud dept on all admin controllers
    before_action :authenticate_admin, unless: :mission_control_jobs?
    before_action :set_paper_trail_whodunnit

    # Shared admin dashboard logic
    def index
      # Authorize access to Users page in AdminPolicy
      # authorize :admin, :users?
    end

    private

    # Use this to protect all admin endpoints
    def authenticate_admin
      # Fulfillment people can only access the shop orders fulfillment endpoint
      if current_user&.fulfillment_person?
        unless shop_orders_fulfillment?
          raise Pundit::NotAuthorizedError
        end
      else
        authorize :admin, :access_admin_endpoints?  # calls AdminPolicy#access_admin_endpoints?
      end
    end

    def mission_control_jobs?
      request.path.start_with?("/admin/jobs")
    end

    def shop_orders_fulfillment?
      controller_name == "shop_orders" && (params[:view] == "fulfillment" || action_name == "show" || action_name == "reveal_address")
    end

    # Handles unauthorized access
    def user_not_authorized
      flash[:alert] = "Hey there buddy u aint no admin!"
      redirect_to(request.referrer || root_path)
    end

    # Track who makes changes in PaperTrail
    def user_for_paper_trail
      current_user&.id
    end
  end
end
