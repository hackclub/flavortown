json.results @results do |project|
  json.partial! "api/v1/projects/project", project: project
end
json.query params[:q]
json.count @results.length
