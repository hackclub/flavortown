class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  # Add Policy Pundit
  include Pundit::Authorization

  def current_user
    if session[:impersonating_user_id] && session[:original_admin_id]
      @current_user ||= User.find_by(id: session[:impersonating_user_id])
    else
      @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
    end
  end
  helper_method :current_user

  def impersonating?
    session[:impersonating_user_id].present? && session[:original_admin_id].present?
  end
  helper_method :impersonating?

  def original_admin
    @original_admin ||= User.find_by(id: session[:original_admin_id]) if session[:original_admin_id]
  end
  helper_method :original_admin
end
