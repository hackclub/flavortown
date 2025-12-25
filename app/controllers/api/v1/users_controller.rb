class Api::V1::UsersController < ApplicationController
  include ApiAuthenticatable

  class_attribute :url_params_model, default: {}
  class_attribute :response_body_model, default: {}

  self.url_params_model = {
    index: {
      page: { type: Integer, desc: "Page number for pagination", required: false }
    }
  }

  self.response_body_model = {
    index: [
      {
        id: Integer,
        slack_id: String,
        display_name: String,
        avatar: String,
        project_ids: [Integer],
        cookies: "Integer || Null" # only if you are opted into the leaderboard
      } 
    ],

    show: {
      id: Integer,
      slack_id: String,
      display_name: String,
      avatar: String,
      project_ids: [Integer],
      cookies: "Integer || Null"
    }
  }

  def index
    @pagy, @users = pagy(User.all, page: params[:page])
  end

  def show
    @user = User.find(params[:id])

  rescue ActiveRecord::RecordNotFound
    render json: { error: "User not found" }, status: :not_found
  end
end
