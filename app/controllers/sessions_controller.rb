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
        user = User.create!(display_name: info.name, email: info.email)
      end

      identity.user = user
      identity.save!

      reset_session
      session[:user_id] = user.id
      redirect_to root_path, notice: "Signed in with Slack"
      nil
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
