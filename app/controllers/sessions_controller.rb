class SessionsController < ApplicationController
  def create
    auth = request.env["omniauth.auth"]
    provider = auth.provider
    uid = auth.uid
    info = auth.info
    cred = auth.credentials

    # provider is a symbol. do not change it to string... equality will fail otherwise

    if provider == :slack && current_user.blank?
      identity = User::Identity.find_or_initialize_by(provider: provider, uid: uid)

      identity.access_token = cred.token
      identity.refresh_token = cred.refresh_token if cred.refresh_token.present?

      user = identity.user
      unless user
        # info.name is overwritten once the callback runs. We're setting something for now...
        user = User.create!(display_name: info.name, email: info.email)
      end

      identity.user = user
      identity.save!

      reset_session
      session[:user_id] = user.id
      target_path = user.setup_complete? ? projects_path : kitchen_path
      redirect_to target_path, notice: "Signed in with Slack"

    elsif provider == :idv
      if current_user.blank?
        redirect_to root_path, alert: "Please sign in with Slack first" and return
      end

      identity = current_user.identities.find_or_initialize_by(provider: provider)
      identity.access_token = cred.token
      identity.refresh_token = cred.refresh_token if cred.respond_to?(:refresh_token) && cred.refresh_token.present?
      identity.save!

      redirect_to kitchen_path, notice: "Identity linked"
    else
      redirect_to root_path, alert: "Authentication failed or user already signed in"
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out"
  end

  def failure
    redirect_to root_path, alert: "Authentication failed"
  end
end
