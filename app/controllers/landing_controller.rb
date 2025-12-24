class LandingController < ApplicationController
  def index
    @prizes = Cache::CarouselPrizesJob.fetch
    @hide_sidebar = true

    if current_user
      redirect_to kitchen_path
    else
      render :index
    end
  end

  def submit_email
    email = params.fetch(:email, "").to_s.strip.downcase

    unless valid_email?(email)
      redirect_to root_path, alert: "Please enter a valid email address."
      return
    end

    existing_user = User.find_by(email: email)

    if existing_user
      FunnelTrackerService.track(
        event_name: "landing_email_submitted",
        email: email,
        properties: { existing_user: true }
      )
      session[:hca_login_hint] = email
      render :hca_signin, layout: false
    else
      FunnelTrackerService.track(
        event_name: "landing_email_submitted",
        email: email,
        properties: { existing_user: false }
      )
      session[:start_email] = email
      redirect_to start_path(email: email)
    end
  end

  private

  def valid_email?(email)
    email.present? && email.match?(URI::MailTo::EMAIL_REGEXP)
  end
end
