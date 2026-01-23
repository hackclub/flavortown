json.extract! @project, :id, :title, :description, :ship_status, :repo_url, :demo_url, :readme_url, :created_at, :updated_at

json.devlog_ids @project.devlogs.map(&:id)
