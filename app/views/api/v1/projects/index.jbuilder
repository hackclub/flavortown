json.projects @projects do |project|
  json.extract! project, :id, :title, :description, :ship_status, :repo_url, :demo_url, :readme_url, :created_at, :updated_at

  json.devlog_ids project.devlogs.map(&:id)
end

json.pagination do
  json.current_page @pagy.page
  json.total_pages @pagy.pages
  json.total_count @pagy.count
  json.next_page @pagy.next
end
