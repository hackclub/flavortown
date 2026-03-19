class Api::V1::LinksController < Api::BaseController
  include ApiAuthenticatable

  # GET /api/v1/links
  # Returns grouped arrays of links: readme_links, project_links, github_links, demo_links
  def index
    projects = Project.where(deleted_at: nil).excluding_shadow_banned

    @readme_links = projects.where.not(readme_url: [nil, ""]).select(:id, :title, :readme_url)
    @demo_links = projects.where.not(demo_url: [nil, ""]).select(:id, :demo_url)
    @github_links = projects.where("repo_url ILIKE ?", "%github.com%").select(:id, :title, :repo_url)

    # project_links are internal ft paths; returns a relative path to avoid needing host
    @project_links = projects.select(:id, :title).map do |p|
      { id: p.id, title: p.title, link: "/projects/#{p.id}" }
    end
  end

  # GET /api/v1/links/demos
  # Returns only demo links for projects that have a demo url
  def demos
    projects = Project.where(deleted_at: nil).excluding_shadow_banned
    limit = params[:limit].to_i.positive? ? params[:limit].to_i.clamp(1, 1000) : nil
    relation = projects.where.not(demo_url: [nil, ""]).select(:id, :demo_url)
    relation = relation.limit(limit) if limit
    @demo_links = relation
  end

  # GET /api/v1/links/repo
  # Returns only repo links for projects that have a repo url
  def repo
    projects = Project.where(deleted_at: nil).excluding_shadow_banned
    limit = params[:limit].to_i.positive? ? params[:limit].to_i.clamp(1, 1000) : nil
    relation = projects.where.not(repo_url: [nil, ""]).select(:id, :repo_url)
    relation = relation.limit(limit) if limit
    @repo_links = relation
  end

  # GET /api/v1/links/readme
  # Returns only readme links for projects that have a readme url
  def readme
    projects = Project.where(deleted_at: nil).excluding_shadow_banned
    limit = params[:limit].to_i.positive? ? params[:limit].to_i.clamp(1, 1000) : nil
    relation = projects.where.not(readme_url: [nil, ""]).select(:id, :readme_url)
    relation = relation.limit(limit) if limit
    @readme_links = relation
  end

  # GET /api/v1/links/projects
  # Returns only project links for all projects
  def projects
    projects = Project.where(deleted_at: nil).excluding_shadow_banned.select(:id)
    limit = params[:limit].to_i.positive? ? params[:limit].to_i.clamp(1, 1000) : nil
    projects = projects.limit(limit) if limit
    @project_links = projects.map { |p| { id: p.id, link: "/projects/#{p.id}" } }
  end
end
