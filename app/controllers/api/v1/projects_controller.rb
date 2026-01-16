class Api::V1::ProjectsController < Api::BaseController
  include ApiAuthenticatable

  class_attribute :description, default: {
    index: "Fetch a list of projects. Ratelimit: 5 reqs/min, 20 reqs/min if searching",
    show: "Fetch a specific project by ID. Ratelimit: 30 reqs/min",
    create: "Create a new project.",
    update: "Update an existing project."
  }

  class_attribute :url_params_model, default: {
    index: {
      page: { type: Integer, desc: "Page number for pagination", required: false },
      query: { type: String, desc: "Search projects by title or description", required: false }
    }
  }

  class_attribute :request_body_model, default: {
    create: {
      title: { type: String, desc: "Project title", required: true },
      description: { type: String, desc: "Project description", required: true },
      repo_url: { type: String, desc: "URL to the source code repository", required: false },
      demo_url: { type: String, desc: "URL to the live demo", required: false },
      readme_url: { type: String, desc: "URL to the README", required: false }
    },
    update: {
      title: { type: String, desc: "Project title", required: false },
      description: { type: String, desc: "Project description", required: false },
      repo_url: { type: String, desc: "URL to the source code repository", required: false },
      demo_url: { type: String, desc: "URL to the live demo", required: false },
      readme_url: { type: String, desc: "URL to the README", required: false }
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
    },

    create: {
      id: Integer,
      title: String,
      description: String,
      repo_url: String,
      demo_url: String,
      readme_url: String,
      devlog_ids: [ Integer ],
      created_at: String,
      updated_at: String
    },

    update: {
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
    projects = Project.where(deleted_at: nil).excluding_shadow_banned.includes(:devlogs)

    if params[:query].present?
      q = "%#{ActiveRecord::Base.sanitize_sql_like(params[:query])}%"
      projects = projects.where(
        "title ILIKE :q OR description ILIKE :q",
        q: q
      )
    end

    @pagy, @projects = pagy(projects, limit: 100)
  end

  def show
    @project = Project.find_by!(id: params[:id], deleted_at: nil)
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Project not found" }, status: :not_found
  end

  def create
    @project = Project.new(project_params)

    ActiveRecord::Base.transaction do
      if @project.save
        @project.memberships.create!(user: current_api_user, role: :owner)
        render :show, status: :created
      else
        render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end
  rescue StandardError => e
    render json: { error: e }, status: :unprocessable_entity
  end

  def update
    @project = Project.find_by!(id: params[:id], deleted_at: nil)

    unless @project.memberships.exists?(user: current_api_user)
      return render json: { error: "You do not have permission to update this project" }, status: :forbidden
    end

    if @project.update(project_params)
      render :show
    else
      render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
     render json: { error: "Project not found" }, status: :not_found
  end

  private

  def project_params
    params.permit(:title, :description, :repo_url, :demo_url, :readme_url)
  end
end
