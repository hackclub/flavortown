class MagicLinksController < ApplicationController
  protect_from_forgery with: :null_session, only: [ :create ]

  def create
    user = User.find_by(email: params[:email])

    if user
      user.generate_magic_link_token!
      MagicLinkMailer.send_magic_link(user).deliver_later
    end

    render json: { message: "If an account exists, a magic link has been sent." }, status: :ok
  end

  def verify
    token = params[:token]
    user = User.find_by(magic_link_token: token)

    if user&.magic_link_valid?
      user.clear_magic_link_token!
      user.regenerate_session_token!
      reset_session
      session[:user_id] = user.id
      session[:session_token] = user.session_token
      target_path = user.setup_complete? ? projects_path : kitchen_path
      redirect_to target_path, notice: "Successfully signed in via magic link"
    else
      redirect_to root_path, alert: "Invalid or expired magic link"
    end
  end
end
