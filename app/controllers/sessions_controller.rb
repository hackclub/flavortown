require "faraday"
require "json"

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

    user_email, display_name, verification_status, slack_id, uid, address = extract_identity_fields(identity_data)
    return redirect_to(root_path, alert: "Authentication failed") if uid.blank?
    return redirect_to(root_path, alert: "Authentication failed") unless User::VALID_VERIFICATION_STATUSES.include?(verification_status)

    identity = User::Identity.find_or_initialize_by(provider: "hack_club", uid: uid)
    identity.access_token = access_token

    user = identity.user || User.find_by(slack_id: slack_id) || User.new
    user.email ||= user_email
    user.display_name = display_name if user.display_name.to_s.strip.blank?
    user.verification_status = verification_status if user.verification_status.to_s != verification_status
    user.slack_id = slack_id if user.slack_id.to_s != slack_id
    user.save!

    identity.user = user
    identity.save!

    reset_session
    session[:user_id] = user.id
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
    conn = Faraday.new(url: "https://hca.dinosaurbbq.org")
    response = conn.get("/api/v1/me") do |req|
      req.headers["Authorization"] = "Bearer #{access_token}"
      req.headers["Accept"] = "application/json"
    end

    unless response.success?
      Rails.logger.warn("Hack Club /me fetch failed with status #{response.status}")
      return nil
    end

    json_payload = JSON.parse(response.body)
    Rails.logger.info(json_payload)
    json_payload["identity"] || {}
  rescue StandardError => e
    Rails.logger.warn("Hack Club /me fetch error: #{e.class}: #{e.message}")
    nil
  end

  def extract_identity_fields(data)
    # Example payload:
    # {"id"=>"ident!Zk9f3K", "verification_status"=>"needs_submission", "primary_email"=>"user@example.com", "first_name"=>"First", "last_name"=>"Last", "slack_id"=>"UXXXXXXX", "address"=>{"street1"=>"123 Test St", "street2"=>"Apt 4B", "city"=>"Testville", "state"=>"TS", "zip"=>"12345", "country"=>"US"}}
    user_email = data["primary_email"].presence.to_s
    first_name = data["first_name"].to_s.strip
    last_name  = data["last_name"].to_s.strip
    display_name = [ first_name, last_name ].reject(&:blank?).join(" ")
    verification_status = data["verification_status"].to_s
    slack_id = data["slack_id"].to_s
    uid = data["id"].to_s
    address = data["address"]
    [ user_email, display_name, verification_status, slack_id, uid, address ]
  end
end
