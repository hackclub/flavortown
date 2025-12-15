module Helper
  class ApplicationController < ::ApplicationController
    include Pundit::Authorization

    layout "helper"

    rescue_from Pundit::NotAuthorizedError, with: :not_authorized

    before_action :authenticate

    def index
      authorize :helper, :access?
    end

    private

    def authenticate
      authorize :helper, :access?
    end

    def not_authorized
      flash[:alert] = "You don't have access to this area."
      redirect_to(request.referrer || root_path)
    end
  end
end
