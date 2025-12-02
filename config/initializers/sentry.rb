Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.send_default_pii = true
  config.enable_logs = true
  config.enabled_patches = [ :logger ]

  config.traces_sample_rate = Rails.env.production? ? 0.1 : 1.0
  config.profiles_sample_rate = Rails.env.production? ? 0.1 : 1.0

  config.rails.report_rescued_exceptions = true
end
