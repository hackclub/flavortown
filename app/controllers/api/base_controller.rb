class Api::BaseController < ActionController::API
  before_action :authenticate_user

  private

  def authenticate_user
    token = request.headers["Authorization"]&.delete_prefix("Bearer ")
    unless token
      render json: { status: "Forbidden", data: "No permission :(" }, status: :forbidden
      return
    end

    @current_user = User.find_by(api_key: token)
    unless @current_user
      render json: { status: "Forbidden", data: "No permission :(" }, status: :forbidden
      nil
    end
  end

  def check_user_is_public(target_user)
    if target_user.nil?
      render json: { status: "Not Found", data: "User not found" }, status: :not_found
      return false
    end
    return true if target_user.public_api?
    return true if target_user == @current_user
    if @current_user
      return true if @current_user.super_admin? || @current_user.admin?
    end
    render json: { status: "Forbidden", data: "No permission :(" }, status: :forbidden
    return false
  end
end
