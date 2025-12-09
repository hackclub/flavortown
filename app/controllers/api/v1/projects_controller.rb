include Rails.application.routes.url_helpers


class Api::V1::ProjectsController < Api::BaseController
  def show
    project = Project.find(params[:id])
    unless project
      render json: { status: "Not Found", data: "Project not found" }, status: :not_found
      return
    end
    owner = project.memberships.owner.first&.user
    unless check_user_is_public(user)
      return
    end

    render json: { status: "Success", data: project_data(project) }, status: :ok
  end


  def index
    projects = Project.all
    limit = params[:limit]&.to_i || 20
    offset = params[:offset]&.to_i || 0
    projects = projects.limit(limit).offset(offset)

    render json: { status: "Success", data: projects.map { |p| project_data(p) } }, status: :ok
  end

  private

  def project_data(project)
    {
      id: project.id,
      title: project.title,
      image: project.image.attached? ? url_for(project.image) : nil,
      description: project.description,
      readme: project.readme_url,
      demo: project.demo_url,
      repo: project.repo_url,
      created_at: project.created_at,
      updated_at: project.updated_at,
      owner: owner ? { id: owner.id, name: owner.display_name } : nil,
      members: project.memberships&.map { |m| { id: m.user.id, name: m.user.display_name } },
      votes_count: project.votes.count,
      devlogs_count: project.devlogs.count,
      demo_video_url: project.demo_video.attached? ? url_for(project.demo_video) : nil,
      banner_url: project.banner.attached? ? url_for(project.banner) : nil
    }
  end
end
