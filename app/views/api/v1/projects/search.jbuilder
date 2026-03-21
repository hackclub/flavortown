json.results @results do |project|
  json.extract! project, :id, :title, :description, :ship_status, :repo_url, :demo_url, :readme_url, :ai_declaration, :created_at, :updated_at
  json.banner_url project.banner.attached? ? url_for(project.banner) : nil

  if admin_api_user?
    json.banned project.deleted_at.present?
    json.shadow_banned project.shadow_banned
    json.shadow_banned_at project.shadow_banned_at
    json.shadow_banned_reason project.shadow_banned_reason
  end
end
json.query params[:q]
json.count @results.length
