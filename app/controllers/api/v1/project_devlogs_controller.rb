class Api::V1::ProjectDevlogsController < Api::BaseController
  include ApiAuthenticatable

  before_action :set_project, only: %i[create update destroy]
  before_action :check_perm!, only: %i[create update destroy]

  MAX_ATTACHMENT_COUNT = 8

  class_attribute :description, default: {
    index: "Fetch a list of devlogs for an project.",
    show: "Fetch a devlog by ID and project ID.",
    create: "Create a new devlog for a project.",
    update: "Update an existing devlog for a project.",
    destroy: "Delete a devlog from a project."
  }

  class_attribute :url_params_model, default: {
    index: {
      page: { type: Integer, desc: "Page number for pagination", required: false }
    }
  }

  class_attribute :request_body_model, default: {
    create: {
      body: { type: String, desc: "The content of the devlog", required: true },
      attachments: { type: Array, of: Multipart, desc: "Attachments to be added to the devlog", required: true }
    },
    update: {
      body: { type: String, desc: "The content of the devlog", required: true },
      attachments: { type: Array, of: Multipart, desc: "Attachments to be added to the devlog", required: false }
    }
  }

  MEDIA_SCHEMA = { url: String, content_type: String }.freeze
  DEVLOG_SCHEMA = {
    id: Integer, body: String, comments_count: Integer, duration_seconds: Integer,
    likes_count: Integer, scrapbook_url: String, created_at: String, updated_at: String,
    media: [ MEDIA_SCHEMA ]
  }.freeze
  PAGINATION_SCHEMA = {
    current_page: Integer, total_pages: Integer,
    total_count: Integer, next_page: "Integer || Null"
  }.freeze

  class_attribute :response_body_model, default: {
    index: { devlogs: [ DEVLOG_SCHEMA ], pagination: PAGINATION_SCHEMA },
    show: DEVLOG_SCHEMA,
    create: DEVLOG_SCHEMA,
    update: DEVLOG_SCHEMA,
    destroy: { message: String }
  }

  def index
    devlogs = Post::Devlog.joins(:post)
                          .includes(attachments_attachments: :blob)
                          .where(posts: { project_id: params[:project_id] })
                          .order(created_at: :desc)

    @pagy, @devlogs = pagy(devlogs)
  end

  def show
    @devlog = Post::Devlog.joins(:post)
                          .includes(attachments_attachments: :blob)
                          .where(posts: { project_id: params[:project_id] })
                          .find_by!(id: params[:id])
  end

  def create
    return render json: { error: "You must link at least one Hackatime project before posting a devlog" }, status: :unprocessable_entity unless @project.hackatime_keys.present?

    @devlog = Post::Devlog.new(devlog_params)
    attach_attachments!(@devlog, params[:attachments]) if params[:attachments].present?

    load_preview_time
    return render json: { error: "Could not get hackatime time" }, status: :unprocessable_entity unless @preview_seconds
    return render json: { error: "You must have at least 15 minutes of coding time logged in Hackatime to create a devlog" }, status: :unprocessable_entity if @preview_seconds < 900

    @devlog.duration_seconds = @preview_seconds
    ActiveRecord::Base.transaction do
      @devlog.save!
      Post.create!(project: @project, user: current_api_user, postable: @devlog)
    end
    render :show, status: :created
  end

  def update
    @devlog = Post::Devlog.joins(:post).find_by!(id: params[:id], posts: { project_id: @project.id })
    prev = @devlog.body

    if @devlog.update(devlog_params)
      @devlog.create_version!(user: current_api_user, previous_body: prev) if prev != @devlog.body
      render :show
    else
      render json: { errors: @devlog.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @devlog = Post::Devlog.joins(:post).find_by!(id: params[:id], posts: { project_id: @project.id })
    @devlog.soft_delete!
    render json: { message: "Devlog deleted successfully" }, status: :ok
  end

  private

  def set_project
    @project = Project.find_by!(id: params[:project_id], deleted_at: nil)
  end

  def check_perm!
    return if @project.memberships.exists?(user: current_api_user)
    render json: { error: "You do not have permission to modify devlogs for this project" }, status: :forbidden
  end

  def devlog_params
    params.permit(:body)
  end

  def attach_attachments!(devlog, attachments)
    files = Array(attachments)

    if files.size > MAX_ATTACHMENT_COUNT
      raise ActiveRecord::RecordInvalid.new(devlog), "Too many attachments (maximum is #{MAX_ATTACHMENT_COUNT})"
    end

    files.each do |uploaded|
      devlog.attachments.attach(
        io: uploaded.tempfile,
        filename: uploaded.original_filename,
        content_type: uploaded.content_type
      )
    end
  end
  def load_preview_time
    current_api_user.with_advisory_lock("devlog_create", timeout_seconds: 10) do
      @preview_seconds = 0
      @project.reload
      hackatime_keys = @project.hackatime_keys

      return @preview_seconds = nil unless hackatime_keys.present?

      result = current_api_user.try_sync_hackatime_data!
      return @preview_seconds = nil unless result

      project_times = result[:projects]
      total_seconds = hackatime_keys.sum { |key| project_times[key].to_i }

      already_logged = Post::Devlog.where(
        id: @project.posts.where(postable_type: "Post::Devlog").select("postable_id::bigint")
      ).sum(:duration_seconds) || 0

      @preview_seconds = [ total_seconds - already_logged, 0 ].max
    end
  end
end
