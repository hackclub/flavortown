class Api::V1::LinksController < Api::BaseController
  include ApiAuthenticatable

  # GET /api/v1/links
  # Returns grouped arrays of links: readme_links, project_links, github_links, demo_links
  def index
    projects = Project.where(deleted_at: nil).excluding_shadow_banned

    @readme_links = projects.where.not(readme_url: [nil, ""]).select(:id, :title, :readme_url)
    @demo_links = projects.where.not(demo_url: [nil, ""]).select(:id, :title, :demo_url)
    @github_links = projects.where("repo_url ILIKE ?", "%github.com%").select(:id, :title, :repo_url)

    # project_links are internal ft paths; returns a relative path to avoid needing host
    @project_links = projects.select(:id, :title).map do |p|
      { id: p.id, title: p.title, link: "/projects/#{p.id}" }
    end
  end
end
