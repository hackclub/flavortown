class Api::V1::DevlogsController < Api::BaseController
  include ApiAuthenticatable

  class_attribute :description, default: {
    index: "Fetch all devlogs across all projects.",
    show: "Fetch a devlog by ID.",
    create: "Create a new devlog.",
    update: "Update an existing devlog."
  }

  class_attribute :url_params_model, default: {
    index: {
      page: { type: Integer, desc: "Page number for pagination", required: false }
    }
  }

  class_attribute :request_body_model, default: {
    create: {
      project_id: { type: Integer, desc: "ID of the project to create the devlog for", required: true },
      devlog: {
        body: { type: String, desc: "Content of the devlog", required: true },
        duration_seconds: { type: Integer, desc: "Duration spent on this update", required: false },
        scrapbook_url: { type: String, desc: "URL to an image/video", required: false },
        tutorial: { type: Boolean, desc: "Is this a tutorial?", required: false }
      }
    },
    update: {
      devlog: {
        body: { type: String, desc: "Content of the devlog", required: false },
        duration_seconds: { type: Integer, desc: "Duration spent on this update", required: false },
        scrapbook_url: { type: String, desc: "URL to an image/video", required: false },
        tutorial: { type: Boolean, desc: "Is this a tutorial?", required: false }
      }
    }
  }

  class_attribute :response_body_model, default: {
    index: {
      devlogs: [
        {
          id: Integer,
          body: String,
          comments_count: Integer,
          duration_seconds: Integer,
          likes_count: Integer,
          scrapbook_url: String,
          created_at: String,
          updated_at: String
        }
      ]
    },

    show: {
      id: Integer,
      body: String,
      comments_count: Integer,
      duration_seconds: Integer,
      likes_count: Integer,
      scrapbook_url: String,
      created_at: String,
      updated_at: String
    },

    create: {
      id: Integer,
      body: String,
      comments_count: Integer,
      duration_seconds: Integer,
      likes_count: Integer,
      scrapbook_url: String,
      created_at: String,
      updated_at: String
    },

    update: {
      id: Integer,
      body: String,
      comments_count: Integer,
      duration_seconds: Integer,
      likes_count: Integer,
      scrapbook_url: String,
      created_at: String,
      updated_at: String
    }
  }

  def index
    devlogs = Post::Devlog.joins(:post).order(created_at: :desc)
    @pagy, @devlogs = pagy(devlogs)
  end

  def show
    @devlog = Post::Devlog.joins(:post).find_by!(id: params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Devlog not found" }, status: :not_found
  end

  def create
    @project = Project.find_by!(id: params[:project_id], deleted_at: nil)
    
    unless @project.memberships.exists?(user: current_api_user)
      return render json: { error: "You do not have permission to post to this project" }, status: :forbidden
    end

    @devlog = Post::Devlog.new(devlog_params)
    @post = Post.new(project: @project, user: current_api_user, postable: @devlog)

    if @post.save
      render :show, status: :created
    else
      render json: { errors: @post.errors.full_messages + @devlog.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Project not found" }, status: :not_found
  end

  def update
    @devlog = Post::Devlog.joins(:post).find_by!(id: params[:id])
    @post = @devlog.post
    
    unless @post.user == current_api_user || @post.project.memberships.exists?(user: current_api_user, role: :owner)
       return render json: { error: "You do not have permission to edit this devlog" }, status: :forbidden
    end

    if @devlog.update(devlog_params)
      render :show
    else
        render json: { errors: @devlog.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Devlog not found" }, status: :not_found
  end

  private

  def devlog_params
    params.require(:devlog).permit(:body, :scrapbook_url, :duration_seconds, :tutorial)
  end
end
