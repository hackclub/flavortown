class Api::V1::ProjectDevlogsController < Api::BaseController
  include ApiAuthenticatable

  class_attribute :description, default: {
    index: "Fetch all devlogs for a specific project."
  }

  class_attribute :url_params_model, default: { }
  class_attribute :request_body_model, default: { }

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
  }

  def index
    project = Project.find(params[:project_id])

    @pagy, @devlogs = pagy(
        project.devlogs
                .where(deleted_at: nil)
                .order(created_at: :desc),
        items: 100
    )
  end
end
