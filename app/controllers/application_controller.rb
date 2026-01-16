class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  # Add Policy Pundit
  include Pundit::Authorization
  include Pagy::Method
  include Achievementable
  include ExtensionUsageTrackable

  before_action :enforce_ban
  before_action :refresh_identity_on_portal_return
  before_action :initialize_cache_counters
  before_action :track_request
  before_action :track_active_user
  before_action :show_pending_achievement_notifications!
  before_action :apply_dev_override_ref
  before_action :allow_profiler
  before_action :bullet_for_admins

  rescue_from StandardError, with: :handle_error
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_invalid_auth_token
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  def current_user(preloads = [])
    return @current_user if defined?(@current_user)

    if session[:user_id]
      scope = User.where(id: session[:user_id])
      scope = scope.eager_load(*Array(preloads)) if preloads.present?
      @current_user = scope.to_a.first
    end
  end
  helper_method :current_user

  def impersonating?
    session[:impersonator_user_id].present? && session[:user_id].present?
  end

  helper_method :impersonating?

  def real_user
    return nil unless session[:impersonator_user_id]
    @real_user ||= User.find_by(id: session[:impersonator_user_id])
  end

  helper_method :real_user

  def pundit_user
    impersonating? ? real_user : current_user
  end

  def tutorial_message(msg)
    flash[:tutorial_messages] ||= []
    if msg.is_a?(Array)
      flash[:tutorial_messages] += msg
    else
      flash[:tutorial_messages] << msg
    end
  end

  def tutorial_messages
    flash[:tutorial_messages] || []
  end
  helper_method :tutorial_messages

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def render_not_found
    render file: Rails.root.join("public/404.html"), status: :not_found, layout: false
  end

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

  def initialize_cache_counters
    Thread.current[:cache_hits] = 0
    Thread.current[:cache_misses] = 0
  end

  def track_request
    RequestCounter.increment
  end

  def track_active_user
    ActiveUserTracker.track(user_id: current_user&.id, session_id: session.id.to_s)
  end

  def apply_dev_override_ref
    return unless Rails.env.development?
    return unless params[:_override_ref].present? && current_user
    return if params[:_override_ref].length > 64

    current_user.update!(ref: params[:_override_ref])
  end

  def allow_profiler
    return unless defined?(Rack::MiniProfiler)
    if current_user&.admin? || Rails.env.development?
      Rack::MiniProfiler.authorize_request
    end
  end

  def bullet_for_admins
    return unless defined?(Bullet)
    Bullet.add_footer = current_user&.admin? || Rails.env.development?
  end

  def refresh_identity_on_portal_return
    return unless params[:portal_status].present? && current_user

    identity = current_user.identities.find_by(provider: "hack_club")
    return unless identity&.access_token.present?

    identity_payload = HCAService.identity(identity.access_token)
    return if identity_payload.blank?

    latest_status = identity_payload["verification_status"].to_s
    return unless User.verification_statuses.key?(latest_status)

    current_user.complete_tutorial_step!(:identity_verified) if %w[pending verified].include?(latest_status)
    current_user.update!(
      verification_status: latest_status,
      ysws_eligible: identity_payload["ysws_eligible"] == true
    )
  rescue StandardError => e
    Rails.logger.warn("Portal return identity refresh failed: #{e.class}: #{e.message}")
  end
end
