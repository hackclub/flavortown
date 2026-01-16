class MyController < ApplicationController
  before_action :require_login

  def balance
    unless turbo_frame_request?
      redirect_to root_path
      return
    end

    @balance = current_user.ledger_entries.includes(:ledgerable).order(created_at: :desc)
  end

  def update_settings
    current_user.update(
      hcb_email: params[:hcb_email].presence,
      send_votes_to_slack: params[:send_votes_to_slack] == "1",
      leaderboard_optin: params[:leaderboard_optin] == "1",
      slack_balance_notifications: params[:slack_balance_notifications] == "1",
      send_notifications_for_followed_devlogs: params[:send_notifications_for_followed_devlogs] == "1",
      special_effects_enabled: params[:special_effects_enabled] == "1"
    )
    redirect_back fallback_location: root_path, notice: "Settings saved"
  end

  def roll_api_key
    current_user.generate_api_key!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "api_key",
          partial: "users/api_key",
          locals: { user: current_user, just_generated: true }
        )
      end

      format.html do
        redirect_back fallback_location: root_path, notice: "API key rolled"
      end
    end
  end

  def cookie_click
    clicks = params[:clicks].to_i.clamp(1, 100)
    current_user.increment!(:cookie_clicks, clicks)
    head :ok
  end

  private

  def require_login
    redirect_to root_path, alert: "Please log in first" and return unless current_user
  end
end
