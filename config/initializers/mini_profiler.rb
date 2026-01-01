if defined?(Rack::MiniProfiler)
  Rack::MiniProfiler.config.enable_hotwire_turbo_drive_support = true
  Rack::MiniProfiler.config.authorization_mode = :allow_authorized
end
