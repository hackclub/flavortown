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

  DEVLOG_SCHEMA = {
    id: Integer, body: String, comments_count: Integer, duration_seconds: Integer,
    likes_count: Integer, scrapbook_url: String, created_at: String, updated_at: String,
    comments: [
      {
        id: Integer,
        author: {
          id: Integer, display_name: String, avatar: String
        },
        body: String,
        created_at: String,
        updated_at: String
      }
    ]
  }.freeze

  PAGINATION_SCHEMA = {
    current_page: Integer, total_pages: Integer,
    total_count: Integer, next_page: "Integer || Null"
  }.freeze

  class_attribute :response_body_model, default: {
    index: { devlogs: [ DEVLOG_SCHEMA ], pagination: PAGINATION_SCHEMA },
    show: DEVLOG_SCHEMA
  }

  def index
    devlogs = Post::Devlog.includes(comments: :user).order(created_at: :desc)
    @pagy, @devlogs = pagy(devlogs)
  end

  def show
    @devlog = Post::Devlog.includes(comments: :user).find_by!(id: params[:id])
  end
end
