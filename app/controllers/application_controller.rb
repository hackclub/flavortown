class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  # Add Policy Pundit
  include Pundit::Authorization

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
  
  def authenticate_user!
    redirect_to root_path, alert: "You must be signed in to access this section" unless current_user
  end
end
