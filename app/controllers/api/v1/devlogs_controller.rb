class Api::V1::DevlogsController < Api::BaseController
  include ApiAuthenticatable

  def index
    limit = params.fetch(:limit, 100).to_i
    return render json: { error: "Limit must be between 1 and 100" }, status: :bad_request if limit < 1 || limit > 100

    devlogs = Post::Devlog.includes(comments: :user).includes(attachments_attachments: :blob).where(deleted_at: nil).order(created_at: :desc)
    @pagy, @devlogs = pagy(devlogs, limit: limit)
  end

  def show
    @devlog = Post::Devlog.includes(comments: :user).includes(attachments_attachments: :blob).where(deleted_at: nil).find_by!(id: params[:id])
  end
end
