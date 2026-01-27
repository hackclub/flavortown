class Api::V1::UsersController < Api::BaseController
  include ApiAuthenticatable

  class_attribute :description, default: {
    index: "Fetch a list of users. Ratelimit: 5 reqs/min",
    show: "Fetch a specific user by ID. Ratelimit: 30 reqs/min"
  }

  class_attribute :url_params_model, default: {
    index: {
      page: { type: Integer, desc: "Page number for pagination", required: false },
      query: { type: String, desc: "Search users by display name or slack ID", required: false }
    }
  }

  USER_BASE = {
    id: Integer, slack_id: String, display_name: String,
    avatar: String, project_ids: [ Integer ], cookies: "Integer || Null"
  }.freeze
  PAGINATION_SCHEMA = {
    current_page: Integer, total_pages: Integer,
    total_count: Integer, next_page: "Integer || Null"
  }.freeze

  class_attribute :response_body_model, default: {
    index: { users: [ USER_BASE ], pagination: PAGINATION_SCHEMA },
    show: USER_BASE.merge(
      vote_count: Integer, like_count: Integer,
      devlog_seconds_total: Integer, devlog_seconds_today: Integer
    )
  }

  def index
    users = User.includes(:projects).all

    if params[:query].present?
      # TODO: if search becomes slow for any reason, add pg_trgm GIN index for ILIKE performance
      q = "%#{ActiveRecord::Base.sanitize_sql_like(params[:query])}%"
      users = users.where("display_name ILIKE :q OR slack_id ILIKE :q", q: q)
    end

    @pagy, @users = pagy(users, page: params[:page], limit: 100)
  end

  def show
    @user = params[:id] == "me" ? current_api_user : User.find(params[:id])
  end
end
