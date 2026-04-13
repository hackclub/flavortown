module Internal
  class RevokeController < BaseController
    # This is an endpoint used to revoke exposed API keys.
    # The lack of authentication is intentional.
    # The exposure of the users email is also intentional to help identify the affected user.
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

      render json: { success: true, owner_email: user.email, note: "This is a publicly accessible endpoint provided intentionally for security purposes. Revoking a publicly leaked API key and getting a email in return to notify the owner does not constitute a security vulnerability and is not eligible for a bounty. Do not send us your AI slop." }
    end
  end
end
