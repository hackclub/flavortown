class Api::V1::ProjectsController < Api::BaseController
  include ApiAuthenticatable

  class_attribute :description, default: {
    index: "Fetch a list of projects. Ratelimit: 5 reqs/min, 20 reqs/min if searching",
    show: "Fetch a specific project by ID. Ratelimit: 30 reqs/min",
    create: "Create a new project.",
    update: "Update an existing project.",
    random: "Fetch random projects."
  }

  class_attribute :url_params_model, default: {
    index: {
      page: { type: Integer, desc: "Page number for pagination", required: false },
      query: { type: String, desc: "Search projects by title or description", required: false }
    },
    random: {
      count: { type: Integer, desc: "Number of random projects to return (1-50, default 1)", required: false },
      approved: { type: String, desc: "Filter to only approved projects (true/false)", required: false },
      shipped: { type: String, desc: "Filter to only shipped projects (true/false)", required: false },
      has_banner: { type: String, desc: "Filter to only projects with a banner image (true/false)", required: false },
      fire: { type: String, desc: "Filter to only well cooked projects (true/false)", required: false }
    }
  }

  class_attribute :request_body_model, default: {
    create: {
      title: { type: String, desc: "Project title", required: true },
      description: { type: String, desc: "Project description", required: true },
      repo_url: { type: String, desc: "URL to the source code repository", required: false },
      demo_url: { type: String, desc: "URL to the live demo", required: false },
      readme_url: { type: String, desc: "URL to the README", required: false },
      ai_declaration: { type: String, desc: "Declaration of AI tools used in this project", required: false }
    },
    update: {
      title: { type: String, desc: "Project title", required: false },
      description: { type: String, desc: "Project description", required: false },
      repo_url: { type: String, desc: "URL to the source code repository", required: false },
      demo_url: { type: String, desc: "URL to the live demo", required: false },
      readme_url: { type: String, desc: "URL to the README", required: false },
      ai_declaration: { type: String, desc: "Declaration of AI tools used in this project", required: false }
    }
  }

  PROJECT_SCHEMA = {
    id: Integer, title: String, description: String, repo_url: String,
    demo_url: String, readme_url: String, ai_declaration: String,
    ship_status: String, devlog_ids: [ Integer ], banner_url: "String || Null",
    created_at: String, updated_at: String
  }.freeze

  PAGINATION_SCHEMA = {
    current_page: Integer, total_pages: Integer,
    total_count: Integer, next_page: "Integer || Null"
  }.freeze

  class_attribute :response_body_model, default: {
    index: { projects: [ PROJECT_SCHEMA ], pagination: PAGINATION_SCHEMA },
    show: PROJECT_SCHEMA,
    create: PROJECT_SCHEMA,
    update: PROJECT_SCHEMA,
    random: { projects: [ PROJECT_SCHEMA ] }
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

  def random
    count = (params[:count] || 1).to_i.clamp(1, 50)

    projects = Project.where(deleted_at: nil).excluding_shadow_banned.includes(:devlogs)
    projects = projects.where(ship_status: :approved) if ActiveModel::Type::Boolean.new.cast(params[:approved])
    projects = projects.where.not(shipped_at: nil) if ActiveModel::Type::Boolean.new.cast(params[:shipped])
    projects = projects.where.associated(:banner_attachment) if ActiveModel::Type::Boolean.new.cast(params[:has_banner])
    projects = projects.fire if ActiveModel::Type::Boolean.new.cast(params[:fire])

    @projects = projects.order("RANDOM()").limit(count)
  end

  def show
    @project = Project.find_by!(id: params[:id], deleted_at: nil)
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
    end
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
  end

  private

  def project_params
    params.permit(:title, :description, :repo_url, :demo_url, :readme_url, :ai_declaration)
  end
end
