json.results @results do |project|
  json.extract! project, :id, :title, :description, :ship_status, :repo_url, :demo_url, :readme_url, :ai_declaration, :created_at, :updated_at
  json.banner_url project.banner.attached? ? url_for(project.banner) : nil
end
json.query params[:q]
json.count @results.length
