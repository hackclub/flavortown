class Api::V1::ProjectsController < Api::BaseController
  include ApiAuthenticatable

  class_attribute :description, default: {
    index: "Fetch a list of projects. Ratelimit: 5 reqs/min, 20 reqs/min if searching",
    show: "Fetch a specific project by ID. Ratelimit: 30 reqs/min"
  }

  class_attribute :url_params_model, default: {
    index: {
      page: { type: Integer, desc: "Page number for pagination", required: false },
      query: { type: String, desc: "Search projects by title or description", required: false }
    }
  }

  class_attribute :response_body_model, default: {
    index: {
      projects: [
        {
          id: Integer,
          title: String,
          description: String,
          repo_url: String,
          demo_url: String,
          readme_url: String,
          devlog_ids: [ Integer ],
          created_at: String,
          updated_at: String
        }
      ]
    },

    show: {
      id: Integer,
      title: String,
      description: String,
      repo_url: String,
      demo_url: String,
      readme_url: String,
      devlog_ids: [ Integer ],
      created_at: String,
      updated_at: String
    }
  }

  def index
    projects = Project.where(deleted_at: nil).includes(:devlogs)

    if params[:query].present?
      q = "%#{ActiveRecord::Base.sanitize_sql_like(params[:query])}%"
      projects = projects.where(
        "title ILIKE :q OR description ILIKE :q",
        q: q
      )
    end

    @pagy, @projects = pagy(projects, items: 100)
  end

  def show
    @project = Project.find_by!(id: params[:id], deleted_at: nil)
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Project not found" }, status: :not_found
  end
end
