json.routes Rails.application.routes.routes.select { |route| route.path.spec.to_s.start_with?("/api") } do |route|
    json.path route.path.spec.to_s.gsub('(.:format)', '')
    json.verb route.verb.to_s.gsub(/[$^]/, '')
    json.controller route.defaults[:controller]
    json.controller_path "app/controllers/" + route.defaults[:controller]
end