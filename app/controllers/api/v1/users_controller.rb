class Api::V1::UsersController < Api::BaseController
  def show
    user = User.find(params[:id])
    unless check_user_is_public(user)
      return
    end

    if user.nil?
      render json: { status: "Not Found", data: "User not found" }, status: :not_found
      return
    end
    render json: { status: "Success", data: user_data(user) }, status: :ok
  end

  def find_by_slack_id
    user = User.find_by(slack_id: params[:slack_id])
    unless check_user_is_public(user)
      return
    end
    if user.nil?
      render json: { status: "Not Found", data: "User not found" }, status: :not_found
      return
    end
    render json: { status: "Success", data: user_data(user) }, status: :ok
  end


  private

  def user_data(user)
    {
      id: user.id,
      email: user.display_name,
      projects_count: user.projects_count,
      votes_count: user.votes_count,
      slack_id: user.slack_id,
      tutorial_steps_count: user.tutorial_steps_completed.count
    }
  end
end