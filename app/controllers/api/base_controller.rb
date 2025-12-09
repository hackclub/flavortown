class Api::BaseController < ActionController::API
  # before_action :authenticate_user

  private

  def authenticate_user
    token = request.headers["Authorization"]&.split(": ")&.last
    unless token
      render json: { status: "Forbidden", data: "No permission :(" }, status: :forbidden
      return
    end

    @current_user = User.find_by(api_key: token)
    unless @current_user
      render json: { status: "Forbidden", data: "No permission :(" }, status: :forbidden unless @current_user
      nil
    end
  end

  def check_user_is_public(target_user)
    return true if target_user.public_api?
    return true if target_user == @current_user
    if @current_user
      return true if @current_user.highest_role == "admin" || @current_user.highest_role == "superadmin"
    end
    render json: { status: "Forbidden", data: "No permission :(" }, status: :forbidden
    false
  end
end
