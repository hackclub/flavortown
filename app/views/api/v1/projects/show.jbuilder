json.extract! @project, :id, :title, :description, :repo_url, :demo_url, :readme_url, :created_at, :updated_at

json.devlog_ids @project.devlogs.map(&:postable_id)
