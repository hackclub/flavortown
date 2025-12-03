class MyController < ApplicationController
  before_action :require_login

  def balance
    unless turbo_frame_request?
      redirect_to root_path
      return
    end
    
    @balance = current_user.ledger_entries.order(created_at: :desc)
  end

  private

  def require_login
    redirect_to root_path, alert: "Please log in first" and return unless current_user
  end
end
