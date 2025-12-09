include Rails.application.routes.url_helpers


class Api::V1::DevlogsController < Api::BaseController
  def index
    project = Project.find_by(id: params[:project_id])

    unless project
      render json: { status: "Not Found", data: "Project not found" }, status: :not_found
      return
    end

    owner = project.memberships.owner.first&.user
    unless check_user_is_public(owner)
      return
    end

    limit = [params[:limit]&.to_i || 20, 50].min
    offset = params[:offset]&.to_i || 0

    devlogs = project.devlogs.limit(limit).offset(offset)

    render json: { status: "Success", data: devlogs_data(devlogs) }, status: :ok
  end

  private

  def devlogs_data(devlogs)
    devlogs.map do |d|
      {
        id: d.id,
        title: d.title,
        description: d.description,
        duration_seconds: d.duration_seconds,
        created_at: d.created_at,
        updated_at: d.updated_at,
        author: d.user ? { 
          id: d.user&.id, 
          name: d.user&.display_name 
          } : nil,
        scrapbook_url: d.scrapbook_url
      }
    end
  end
end
