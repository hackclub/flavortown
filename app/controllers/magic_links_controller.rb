class MagicLinksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :create ]

  def create
    user = User.find_by(email: params[:email])

    if user
      user.generate_magic_link_token!
      MagicLinkMailer.send_magic_link(user).deliver_later
      render json: { message: "Magic link sent to #{params[:email]}" }, status: :ok
    else
      render json: { error: "User not found" }, status: :not_found
    end
  end

  def verify
    token = params[:token]
    user = User.find_by(magic_link_token: token)

    if user&.magic_link_valid?
      user.clear_magic_link_token!
      reset_session
      session[:user_id] = user.id
      redirect_to projects_path, notice: "Successfully signed in via magic link"
    else
      redirect_to root_path, alert: "Invalid or expired magic link"
    end
  end
end
