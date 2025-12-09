module ApiAuthenticatable
  extend ActiveSupport::Concern

  included do
    skip_before_action :verify_authenticity_token
    before_action :authenticate_api_key
  end

  private

  def authenticate_api_key
    api_key = request.headers["Authorization"]&.remove("Bearer ")

    unless api_key.present?
      render json: { error: "Missing Authorization header" }, status: :unauthorized
      return false
    end

    @current_api_user = User.find_by(api_key: api_key) if api_key.present?

    unless @current_api_user
      render json: { error: "Invalid API key" }, status: :unauthorized
      false
    end
  end

  def current_api_user
    @current_api_user
  end
end
