json.projects @projects do |project|
  json.extract! project, :id, :title, :description, :repo_url, :demo_url, :readme_url, :created_at, :updated_at
end

json.pagination do
  json.current_page @projects.current_page
  json.per_page @projects.limit_value
  json.total_pages @projects.total_pages
  json.total_count @projects.total_count
end