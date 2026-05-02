class Api::V1::LinksController < Api::BaseController
  include ApiAuthenticatable

  # GET /api/v1/links
  # Returns grouped arrays of links: readme_links, project_links, repo_links, demo_links
  def index
    projects = Project.where(deleted_at: nil).excluding_shadow_banned

    @readme_links = projects.where.not(readme_url: [ nil, "" ]).select(:id, :title, :readme_url)
    @demo_links   = projects.where.not(demo_url: [ nil, "" ]).select(:id, :title, :demo_url)
    @repo_links   = projects.where.not(repo_url: [ nil, "" ]).select(:id, :title, :repo_url)

    # project_links are internal ft paths; returns a relative path to avoid needing host
    @project_links = projects.select(:id, :title).map do |p|
      { id: p.id, title: p.title, link: project_path(p) }
    end
  end

  # GET /api/v1/links/demos
  # Returns only demo links for projects that have a demo url
  def demos
    projects = Project.where(deleted_at: nil).excluding_shadow_banned
    limit = limit_param
    relation = projects.where.not(demo_url: [ nil, "" ]).select(:id, :title, :demo_url)
    relation = relation.order(:id).limit(limit) if limit
    @demo_links = relation
  end

  # GET /api/v1/links/repo
  # Returns only repo links for projects that have a repo url
  def repo
    projects = Project.where(deleted_at: nil).excluding_shadow_banned
    limit = limit_param
    relation = projects.where.not(repo_url: [ nil, "" ]).select(:id, :title, :repo_url)
    relation = relation.order(:id).limit(limit) if limit
    @repo_links = relation
  end

  # GET /api/v1/links/readme
  # Returns only readme links for projects that have a readme url
  def readme
    projects = Project.where(deleted_at: nil).excluding_shadow_banned
    limit = limit_param
    relation = projects.where.not(readme_url: [ nil, "" ]).select(:id, :title, :readme_url)
    relation = relation.order(:id).limit(limit) if limit
    @readme_links = relation
  end

  # GET /api/v1/links/projects
  # Returns only project links for all projects
  def projects
    projects = Project.where(deleted_at: nil).excluding_shadow_banned.select(:id, :title)
    limit = limit_param
    projects = projects.order(:id).limit(limit) if limit
    @project_links = projects.map { |p| { id: p.id, title: p.title, link: project_path(p) } }
  end

  private

  def limit_param
    value = params[:limit].to_i
    return nil unless value.positive?

    # No Limit cap
    value.clamp(1, Float::INFINITY)
  end
end
