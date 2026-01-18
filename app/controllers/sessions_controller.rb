class SessionsController < ApplicationController
  def create
    auth = request.env["omniauth.auth"]
    provider = auth.provider
    cred = auth.credentials

    # provider is a symbol. do not change it to string... equality will fail otherwise
    unless provider == :hack_club && current_user.blank?
      Sentry.capture_message("Authentication failed: invalid provider or user already signed in", level: :warning, extra: { provider:, user_signed_in: current_user.present? })
      return redirect_to(root_path, alert: "Authentication failed or user already signed in")
    end

    access_token = cred&.token.to_s
    identity_data = fetch_hack_club_identity(access_token)
    if identity_data.blank?
      Sentry.capture_message("Authentication failed: unable to fetch identity data", level: :warning)
      return redirect_to(root_path, alert: "Authentication failed")
    end

    user_email, display_name, verification_status, ysws_eligible, slack_id, uid, _, first_name, last_name = extract_identity_fields(identity_data)
    if uid.blank?
      return redirect_to(root_path, alert: "Your Hack Club account is broken. Please contact support.")
    end
    if slack_id.blank?
      return redirect_to(root_path, alert: "Your Hack Club account is not linked to a Slack account! Please contact support.")
    end
    unless User.verification_statuses.key?(verification_status)
      return redirect_to(root_path, alert: "Your Hack Club account is broken. Please contact support.")
    end

    identity = User::Identity.find_or_initialize_by(provider: "hack_club", uid: uid)
    user = identity.user || User.find_by(slack_id: slack_id) || User.new

    if identity.new_record? && user.persisted?
      existing_identity = user.identities.find_by(provider: "hack_club")
      if existing_identity
        Sentry.capture_message(
          "User UID changed on HCA side",
          level: :info,
          extra: { user_id: user.id, old_uid: existing_identity.uid, new_uid: uid, slack_id: slack_id }
        )
        identity = existing_identity
        identity.uid = uid
      end
    end

    identity.access_token = access_token
    is_new_user = user.new_record?
    user.email ||= user_email
    user.display_name = display_name if user.display_name.to_s.strip.blank?
    user.first_name = first_name if first_name.present?
    user.last_name = last_name if last_name.present?
    user.verification_status = verification_status if user.verification_status.to_s != verification_status
    user.ysws_eligible = ysws_eligible if user.ysws_eligible != ysws_eligible
    user.slack_id = slack_id if user.slack_id.to_s != slack_id

    if is_new_user && cookies[:referral_code].present? && cookies[:referral_code].length <= 64
      user.ref = cookies[:referral_code]
    end

    begin
      user.save!
    rescue ActiveRecord::RecordInvalid => e
      Sentry.capture_exception(e, extra: {
        user_id: user.id,
        user_errors: user.errors.full_messages,
        slack_id: slack_id,
        uid: uid,
        is_new_user: is_new_user
      })
      return redirect_to(root_path, alert: "Unable to save your account. Please contact support.")
    end

    identity.user = user
    begin
      identity.save!
    rescue ActiveRecord::RecordInvalid => e
      Sentry.capture_exception(e, extra: {
        identity_id: identity.id,
        identity_errors: identity.errors.full_messages,
        user_id: user.id,
        provider: identity.provider,
        uid: identity.uid,
        existing_identity_for_user: user.identities.find_by(provider: "hack_club")&.attributes&.except("access_token_ciphertext", "refresh_token_ciphertext")
      })
      return redirect_to(root_path, alert: "Unable to link your Hack Club account. Please contact support.")
    end

    if is_new_user
      FunnelTrackerService.track(
        event_name: "first_login",
        user: user,
        properties: { referral_code: user.ref }
      )

      if user.email.present?
        FunnelTrackerService.link_events_to_user(user, user.email)
      end
    end

    SyncSlackDisplayNameJob.perform_later(user)
    CheckSlackMembershipJob.perform_later(user)

    session[:user_id] = user.id

    # /start
    if session.delete(:start_flow)
      FunnelTrackerService.track(
        event_name: "start_flow_signin",
        user: user
      )

      apply_start_flow_data!(user)
      user.complete_tutorial_step!(:first_login)
      session[:show_welcome_overlay] = true
      redirect_to kitchen_path
      return
    end

    redirect_to(user.setup_complete? ? projects_path : kitchen_path, notice: "Signed in with Hack Club")
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out"
  end

  def failure
    redirect_to root_path, alert: "Authentication failed"
  end

  private

  def fetch_hack_club_identity(access_token)
    # https://hca.dinosaurbbq.org/docs/oauth-guide
    HCAService.identity(access_token)
  end

  def extract_identity_fields(data)
    # Example payload:
    # {"id"=>"ident!Zk9f3K", "verification_status"=>"needs_submission", "ysws_eligible"=>true, "primary_email"=>"user@example.com", "first_name"=>"First", "last_name"=>"Last", "slack_id"=>"UXXXXXXX", "address"=>{"street1"=>"123 Test St", "street2"=>"Apt 4B", "city"=>"Testville", "state"=>"TS", "zip"=>"12345", "country"=>"US"}}
    user_email = data["primary_email"].presence.to_s
    first_name = data["first_name"].to_s.strip
    last_name  = data["last_name"].to_s.strip
    display_name = [ first_name, last_name ].reject(&:blank?).join(" ")
    verification_status = data["verification_status"].to_s
    ysws_eligible = data["ysws_eligible"] == true
    slack_id = data["slack_id"].to_s
    uid = data["id"].to_s
    address = data["address"]
    [ user_email, display_name, verification_status, ysws_eligible, slack_id, uid, address, first_name, last_name ]
  end

  def apply_start_flow_data!(user)
    session_data = {
      start_display_name: session[:start_display_name],
      start_project_attrs: session[:start_project_attrs],
      start_devlog_body: session[:start_devlog_body],
      start_devlog_attachment_ids: session[:start_devlog_attachment_ids]
    }

    result = StartFlowService.new(user: user, session_data: session_data).call

    unless result.success?
      flash[:alert] = result.errors.join(". ")
    end

    result
  ensure
    clear_start_flow_session!
  end

  def clear_start_flow_session!
    session.delete(:start_display_name)
    session.delete(:start_email)
    session.delete(:start_project_attrs)
    session.delete(:start_devlog_body)
    session.delete(:start_devlog_attachment_ids)
  end
end
