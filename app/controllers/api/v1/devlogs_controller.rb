class Api::V1::DevlogsController < Api::BaseController
  include ApiAuthenticatable

  class_attribute :description, default: {
    index: "Fetch all devlogs across all projects.",
    show: "Fetch a devlog by ID."
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
      ],
      pagination: {
        current_page: Integer,
        total_pages: Integer,
        total_count: Integer,
        next_page: Integer
      }
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
    devlogs = Post::Devlog.joins(:post).order(created_at: :desc)
    @pagy, @devlogs = pagy(devlogs)
  end

  def show
    @devlog = Post::Devlog.joins(:post).find_by!(id: params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Devlog not found" }, status: :not_found
  end
end
