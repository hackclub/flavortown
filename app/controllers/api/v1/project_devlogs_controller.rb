class Api::V1::ProjectDevlogsController < Api::BaseController
  include ApiAuthenticatable

  def index
    limit = params.fetch(:limit, 100).to_i
    return render json: { error: "Limit must be between 1 and 100" }, status: :bad_request if limit < 1 || limit > 100

    project = Project.find_by!(id: params[:project_id], deleted_at: nil)

    @pagy, @devlogs = pagy(
        project.devlogs
                .where(deleted_at: nil)
                .order(created_at: :desc),
        limit: limit
    )
  end
end
