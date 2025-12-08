class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  # Add Policy Pundit
  include Pundit::Authorization
  include Pagy::Method

  before_action :enforce_ban

  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_invalid_auth_token
  rescue_from StandardError, with: :handle_error

  def current_user(preloads = [])
    return @current_user if defined?(@current_user)

    if session[:user_id] && session[:session_token]
      scope = User.where(id: session[:user_id])
      scope = scope.includes(*preloads) unless preloads.empty?
      user = scope.first
      @current_user = user if user&.valid_session_token?(session[:session_token])
    end
  end
  helper_method :current_user

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_to(request.referrer || root_path)
  end

  def handle_invalid_auth_token
    reset_session
    redirect_to root_path, alert: "Your session has expired. Please try again."
  end

  def handle_error(exception)
    event_id = Sentry.last_event_id || Sentry.capture_exception(exception)&.event_id
    @trace_id = event_id || request.request_id
    @exception = exception if current_user&.admin?

    raise exception if Rails.env.development? && !params[:show_error_page]

    respond_to do |format|
      format.html { render "errors/internal_server_error", status: :internal_server_error, layout: "application" }
      format.json { render json: { error: "Internal server error", trace_id: @trace_id }, status: :internal_server_error }
    end
  end

  def enforce_ban
    return unless current_user&.banned?
    return if controller_name == "kitchen" || controller_name == "sessions"

    redirect_to kitchen_path, alert: "Your account has been banned."
  end
end
