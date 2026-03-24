class Api::V1::Admin::BaseController < Api::BaseController
  include ApiAuthenticatable
  include Pundit::Authorization

  before_action :require_admin!

  private

  def require_admin!
    authorize :admin, :access_admin_endpoints?
  end

  def pundit_user
    current_api_user
  end
end
