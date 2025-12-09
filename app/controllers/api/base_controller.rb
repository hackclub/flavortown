class Api::BaseController < ActionController::API
  before_action :authenticate_user

  private

  def authenticate_user
    token = request.headers["Authorization"]&.split(": ")&.last
    unless token
      render json: { status: "Forbidden", data: "No permission :("}, status: :forbidden
    end
    @current_user = User.find_by(api_token: token)
    unless @current_user
      render json: { status: "Forbidden", data: "No permission :("}, status: :forbidden unless @current_user
    end
    
  end

  def check_user_is_public(target_user)
    return if target_user.public_profile?
    return if target_user == @current_user
    return if @current_user.admin? || @current_user.moderator?

    render json: { status: "Forbidden", data: "No permission :("}, status: :forbidden
  end

end