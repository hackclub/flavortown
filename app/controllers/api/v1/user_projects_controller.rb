class Api::V1::UserProjectsController < Api::BaseController
  include ApiAuthenticatable

  private

  def admin_api_user?
    current_api_user&.admin?
  end
  helper_method :admin_api_user?

  public

  def index
    user = params[:user_id] == "me" ? current_api_user : User.find(params[:user_id])

    limit = params.fetch(:limit, 100).to_i
    return render json: { error: "Limit must be between 1 and 100" }, status: :bad_request if limit < 1 || limit > 100

    projects = user.projects.where(deleted_at: nil).excluding_shadow_banned.includes(:devlogs)

    @pagy, @projects = pagy(projects, page: params[:page], limit: limit)
  end
end
