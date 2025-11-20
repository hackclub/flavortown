Rails.application.config.middleware.use OmniAuth::Builder do
    # Hack Club Account via generic OAuth2
    provider :oauth2,
      Rails.application.credentials.dig(:hack_club, :client_id) || ENV["HACK_CLUB_CLIENT_ID"],
      Rails.application.credentials.dig(:hack_club, :client_secret) || ENV["HACK_CLUB_CLIENT_SECRET"],
      {
        name: :hack_club,
        scope: "email name slack_id verification_status",
        callback_path: "/oauth/callback",
        client_options: {
          site:          "https://hca.dinosaurbbq.org",
          authorize_url: "/oauth/authorize",
          token_url:     "/oauth/token"
        }
      }
end
