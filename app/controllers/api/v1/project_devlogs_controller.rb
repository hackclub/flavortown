class Api::V1::ProjectDevlogsController < Api::BaseController
  include ApiAuthenticatable

  class_attribute :description, default: {
    index: "Fetch a list of devlogs for an project.",
    show: "Fetch a devlog by ID and project ID."
  }

  class_attribute :url_params_model, default: {
    index: {
      page: { type: Integer, desc: "Page number for pagination", required: false }
    }
  }

  class_attribute :response_body_model, default: {
    index: {
      devlogs: [
        {
          id: Integer,
          body: String,
          comments_count: Integer,
          duration_seconds: Integer,
          likes_count: Integer,
          scrapbook_url: String,
          created_at: String,
          updated_at: String
        }
      ]
    },

    show: {
      id: Integer,
      body: String,
      comments_count: Integer,
      duration_seconds: Integer,
      likes_count: Integer,
      scrapbook_url: String,
      created_at: String,
      updated_at: String
    }
  }

  def index
    devlogs = Post::Devlog.joins(:post)
                          .where(posts: { project_id: params[:project_id] })
                          .order(created_at: :desc)

    @pagy, @devlogs = pagy(devlogs)
  end

  def show
    @devlog = Post::Devlog.joins(:post)
                          .where(posts: { project_id: params[:project_id] })
                          .find_by!(id: params[:id])

  rescue ActiveRecord::RecordNotFound
    render json: { error: "Devlog not found" }, status: :not_found
  end
end
