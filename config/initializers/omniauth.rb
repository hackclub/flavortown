Rails.application.config.middleware.use OmniAuth::Builder do
    provider :openid_connect,
    name: :slack,
    scope: [ :openid, :profile, :email ],
    response_type: :code,
    discovery: true,
    issuer: "https://slack.com",
    uid_field: "https://slack.com/user_id",
    client_options: {
      identifier:   Rails.application.credentials.dig(:slack, :client_id) || ENV["SLACK_CLIENT_ID"],
      secret:       Rails.application.credentials.dig(:slack, :client_secret) || ENV["SLACK_CLIENT_SECRET"],
      redirect_uri: Rails.application.credentials.dig(:slack, :redirect_uri) || ENV["SLACK_REDIRECT_URI"]
    }
end
