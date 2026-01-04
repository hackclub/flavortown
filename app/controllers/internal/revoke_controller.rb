module Internal
  class RevokeController < BaseController
    def create
      token = params[:token]

      unless token.present?
        return render json: { success: false }, status: :bad_request
      end

      user = User.find_by(api_key: token)

      unless user
        return render json: { success: false }, status: :not_found
      end

      user.generate_api_key!

      render json: { success: true, owner_email: user.email }
    end
  end
end
