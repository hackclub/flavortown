class SessionsController < ApplicationController
  def create
    auth = request.env["omniauth.auth"]
    provider = auth.provider
    cred = auth.credentials

    # provider is a symbol. do not change it to string... equality will fail otherwise
    return redirect_to(root_path, alert: "Authentication failed or user already signed in") unless provider == :hack_club && current_user.blank?

    access_token = cred&.token.to_s
    identity_data = fetch_hack_club_identity(access_token)
    return redirect_to(root_path, alert: "Authentication failed") if identity_data.blank?

    user_email, display_name, verification_status, ysws_eligible, slack_id, uid, _, first_name, last_name = extract_identity_fields(identity_data)
    return redirect_to(root_path, alert: "Authentication failed") if uid.blank?
    return redirect_to(root_path, alert: "Authentication failed") if slack_id.blank?
    return redirect_to(root_path, alert: "Authentication failed") unless User.verification_statuses.key?(verification_status)

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
    if user.complete_tutorial_step! :first_login
      tutorial_message "Hello! You just signed in!"
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
end
