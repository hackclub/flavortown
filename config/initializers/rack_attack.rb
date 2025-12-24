require "rack/attack"

# these give a lot of data and wont need to be queried often
Rack::Attack.throttle("api/store_all/auth", limit: 5, period: 1.minute) do |req|
  if req.path == "/api/v1/store"
    req.env["HTTP_AUTHORIZATION"]
  end
end

Rack::Attack.throttle("api/projects_all/auth", limit: 50, period: 1.minute) do |req|
  if req.path == "/api/v1/projects" && req.params["query"].blank?
    req.env["HTTP_AUTHORIZATION"]
  end
end

# this one is fine to query more cause its with search
Rack::Attack.throttle("api/projects_all_with_query/auth", limit: 40, period: 1.minute) do |req|
  if req.path == "/api/v1/projects" && req.params["query"].present?
    req.env["HTTP_AUTHORIZATION"]
  end
end

# these makes sense to query more often
Rack::Attack.throttle("api/store/auth", limit: 30, period: 1.minute) do |req|
  if req.path.start_with?("/api/v1/store/")
    req.env["HTTP_AUTHORIZATION"]
  end
end

Rack::Attack.throttle("api/projects/auth", limit: 30, period: 1.minute) do |req|
  if req.path.start_with?("/api/v1/projects/")
    req.env["HTTP_AUTHORIZATION"]
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
