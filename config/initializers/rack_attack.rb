require "rack/attack"

# these give a lot of data and wont need to be queried often
Rack::Attack.throttle("api/store_all/ip", limit: 5, period: 1.minute) do |req|
  if req.path == "/api/v1/store"
    req.ip
  end
end

Rack::Attack.throttle("api/projects_all/ip", limit: 5, period: 1.minute) do |req|
  if req.path == "/api/v1/projects"
    req.ip
  end
end

# these makes sense to query more often
Rack::Attack.throttle("api/store/ip", limit: 30, period: 1.minute) do |req|
  if req.path.start_with?("/api/v1/store/")
    req.ip
  end
end

Rack::Attack.throttle("api/projects/ip", limit: 30, period: 1.minute) do |req|
  if req.path.start_with?("/api/v1/projects/")
    req.ip
  end
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
