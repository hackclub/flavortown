require "rack/attack"

# rate limit the API to 60 req/min...
Rack::Attack.throttle("api/sustained", limit: 60, period: 1.minute) do |req|
  (req.env["HTTP_AUTHORIZATION"] || req.ip) if req.path.start_with?("/api/")
end

# ...but with a burst of up to 20 reqs per 5 sec
Rack::Attack.throttle("api/burst", limit: 20, period: 5.seconds) do |req|
  (req.env["HTTP_AUTHORIZATION"] || req.ip) if req.path.start_with?("/api/")
end

# rate limit internal revoke endpoint to 500 req/hr
Rack::Attack.throttle("internal/revoke", limit: 500, period: 1.hour) do |req|
  req.ip if req.path == "/internal/revoke" && req.post?
end

Rack::Attack.throttled_responder = lambda do |req|
  body = {
    error: "rate_limited",
    message: "Too many requests. Please slow down."
  }.to_json

  [
    429,
    {
      "Content-Type" => "application/json",
      "Retry-After" => req.env["rack.attack.match_data"][:period].to_s
    },
    [ body ]
  ]
end
