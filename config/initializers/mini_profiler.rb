if defined?(Rack::MiniProfiler)
  Rack::MiniProfiler.config.enable_hotwire_turbo_drive_support = true

  # only admin
  Rack::MiniProfiler.config.authorization_mode = :allow_authorized

  Rails.application.config.to_prepare do
    Rack::MiniProfiler.config.pre_authorize_cb = lambda { |_env| true }

    Rack::MiniProfiler.config.authorize_cb = lambda { |request|
      user = request.env["warden"]&.user
      user&.admin? || false
    }
  end
end
