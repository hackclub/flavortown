class Api::V1::UsersController < Api::BaseController
  include ApiAuthenticatable

  class_attribute :description, default: {
    index: "Fetch a list of users. Ratelimit: 5 reqs/min",
    show: "Fetch a specific user by ID. Ratelimit: 30 reqs/min"
  }

  class_attribute :url_params_model, default: {
    index: {
      page: { type: Integer, desc: "Page number for pagination", required: false }
    }
  }

  class_attribute :response_body_model, default: {
    index: {
      users: [
        {
          id: Integer,
          slack_id: String,
          display_name: String,
          avatar: String,
          project_ids: [ Integer ],
          cookies: "Integer || Null" # only if they are opted into the leaderboard
        }
      ]
    },

    show: {
      id: Integer,
      slack_id: String,
      display_name: String,
      avatar: String,
      project_ids: [ Integer ],
      vote_count: Integer,
      like_count: Integer,
      devlog_seconds_total: Integer,
      devlog_seconds_today: Integer,
      cookies: "Integer || Null" # only if they are opted into the leaderboard
    }
  }

  def index
    @pagy, @users = pagy(User.includes(:projects).all, page: params[:page], limit: 100)
  end

  def show
    if params[:id] == "me"
      @user = @current_api_user
    else
      @user = User.find(params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "User not found" }, status: :not_found
  end
end
