# app/controllers/admin/application_controller.rb
module Admin
  class ApplicationController < ::ApplicationController
    include Pundit::Authorization

    layout "admin"

    # Rescue all Pundit authorization errors
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

    # Optional before_action to enforce admin/fraud dept on all admin controllers
    before_action :preload_roles
    before_action :authenticate_admin, unless: :mission_control_jobs?
    before_action :set_paper_trail_whodunnit

    # Shared admin dashboard logic
    def index
      authorize :admin, :index?
    end

    private

    # Use this to protect all admin endpoints
    def authenticate_admin
      Rails.logger.info "session[:user_id]: #{session[:user_id].inspect}"
      Rails.logger.info "current_user: #{current_user.inspect}"
      Rails.logger.info "current_user.admin?: #{current_user&.admin?.inspect}"
      Rails.logger.info "current_user.admin.role_assignments: #{current_user&.role_assignments&.map(&:role).inspect}"
      # Fulfillment people can only access the shop orders fulfillment endpoint
      # But admins can access everything
      if current_user&.fulfillment_person? && !current_user&.admin? && !current_user&.fraud_dept?
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

    def preload_roles
      current_user(:role_assignments)
    end
  end
end
