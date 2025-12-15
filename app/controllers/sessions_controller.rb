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
      Sentry.capture_message("Authentication failed: uid is blank", level: :warning, extra: { identity_data: })
      return redirect_to(root_path, alert: "Authentication failed")
    end
    if slack_id.blank?
      Sentry.capture_message("Authentication failed: slack_id is blank", level: :warning, extra: { uid: })
      return redirect_to(root_path, alert: "Authentication failed")
    end
    unless User.verification_statuses.key?(verification_status)
      Sentry.capture_message("Authentication failed: invalid verification_status", level: :warning, extra: { verification_status: })
      return redirect_to(root_path, alert: "Authentication failed")
    end

    identity = User::Identity.find_or_initialize_by(provider: "hack_club", uid: uid)
    identity.access_token = access_token

    user = identity.user || User.find_by(slack_id: slack_id) || User.new
    user.email ||= user_email
    user.display_name = display_name if user.display_name.to_s.strip.blank?
    user.first_name = first_name if first_name.present?
    user.last_name = last_name if last_name.present?
    user.verification_status = verification_status if user.verification_status.to_s != verification_status
    user.ysws_eligible = ysws_eligible if user.ysws_eligible != ysws_eligible
    user.slack_id = slack_id if user.slack_id.to_s != slack_id
    user.save!

    identity.user = user
    identity.save!

    SyncSlackDisplayNameJob.perform_later(user)

    session[:user_id] = user.id

    # This is sorta temp too!
    if session.delete(:start_flow)
      apply_start_flow_data!(user)
      user.complete_tutorial_step!(:first_login)
      tutorial_message [
        "Welcome to Flavortown, Chef! Your project and devlog have been created.",
        "You've unlocked free stickers! Verify your identity to redeem them."
      ]
      redirect_to shop_path, notice: "Welcome to Flavortown! You've unlocked free stickers."
      return
    end

    if user.complete_tutorial_step! :first_login
      tutorial_message [
        "Hello Chef! You just signed in — welcome to Flavortown! Are you excited for your first day?",
        "You'll first have to complete a set of quick setup steps in the Kitchen before you can start cooking up some projects.",
        "And your reward will be free stickers! Excited? Let's get cookin'!"
    ]
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

  # this is very obviously temp and vibe coded
  def apply_start_flow_data!(user)
    # 1. Apply display name from session (only if user doesn't have one from HCA)
    start_display_name = session[:start_display_name].to_s.strip
    if user.display_name.to_s.strip.blank? && start_display_name.present?
      user.display_name = start_display_name
      user.save! if user.valid?
    end

    # 2. Create project from session data (using model validations)
    project_attrs = session[:start_project_attrs] || {}
    project_attrs = project_attrs.slice("title", "description") # extra safety

    return if project_attrs["title"].to_s.strip.blank?

    project = Project.new(
      title: project_attrs["title"],
      description: project_attrs["description"]
    )

    unless project.valid?
      Rails.logger.warn("Start flow project invalid: #{project.errors.full_messages.join(', ')}")
      return
    end

    project.save!
    project.memberships.create!(user: user, role: :owner)
    user.complete_tutorial_step!(:create_project)

    # 3. Create devlog from session data (using model validations)
    devlog_body = session[:start_devlog_body].to_s
    attachment_ids = session[:start_devlog_attachment_ids] || []

    if devlog_body.present? || attachment_ids.any?
      devlog = Post::Devlog.new(body: devlog_body)

      # Re-attach blobs from signed blob IDs
      if attachment_ids.any?
        attachment_ids.each do |signed_id|
          blob = ActiveStorage::Blob.find_signed(signed_id)
          devlog.attachments.attach(blob) if blob
        rescue ActiveSupport::MessageVerifier::InvalidSignature
          Rails.logger.warn("Start flow: Invalid signed blob ID: #{signed_id}")
        end
      end

      if devlog.valid?
        devlog.save!
        Post.create!(project: project, user: user, postable: devlog)
        user.complete_tutorial_step!(:post_devlog)
      else
        Rails.logger.warn("Start flow devlog invalid: #{devlog.errors.full_messages.join(', ')}")
      end
    end
  rescue StandardError => e
    Rails.logger.error("Start flow data application failed: #{e.class}: #{e.message}")
    Sentry.capture_exception(e, extra: { user_id: user.id })
  ensure
    clear_start_flow_session!
  end

  def clear_start_flow_session!
    session.delete(:start_display_name)
    session.delete(:start_project_attrs)
    session.delete(:start_devlog_body)
    session.delete(:start_devlog_attachment_ids)
  end
end
