class Api::V1::ProjectDevlogsController < Api::BaseController
  include ApiAuthenticatable

  class_attribute :description, default: {
    index: "Fetch a list of devlogs for an project.",
    show: "Fetch a devlog by ID and project ID.",
    create: "Create a new devlog for a project.",
    update: "Update an existing devlog for a project."
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
          updated_at: String,
          media: [
            {
              url: String,
              content_type: String
            }
          ]
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
      updated_at: String,
      media: [
        {
          url: String,
          content_type: String
        }
      ]
    },

    create: {
      id: Integer,
      body: String,
      comments_count: Integer,
      duration_seconds: Integer,
      likes_count: Integer,
      scrapbook_url: String,
      created_at: String,
      updated_at: String,
      media: [
        {
          url: String,
          content_type: String
        }
      ]
    },

    update: {
      id: Integer,
      body: String,
      comments_count: Integer,
      duration_seconds: Integer,
      likes_count: Integer,
      scrapbook_url: String,
      created_at: String,
      updated_at: String,
      media: [
        {
          url: String,
          content_type: String
        }
      ]
    }
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

  rescue ActiveRecord::RecordNotFound
    render json: { error: "Devlog not found" }, status: :not_found
  end

  def create
    @project = Project.find_by!(id: params[:project_id], deleted_at: nil)

    # check permissions
    unless @project.memberships.exists?(user: current_api_user)
      render json: { error: "You do not have permission to add a devlog for this project" }, status: :forbidden
      return
    end

    attachments_param = params[:attachments]

    @devlog = Post::Devlog.new(devlog_params)
    attach_attachments!(@devlog, attachments_param) if attachments_param.present?

    # get hackatime time
    render json: { error: "You must link at least one Hackatime project before posting a devlog" }, status: :unprocessable_entity and return unless @project.hackatime_keys.present?
    load_preview_time
    @devlog.duration_seconds = @preview_seconds
    unless @preview_seconds
      render json: { error: "Could not get hackatime time" }, status: :unprocessable_entity and return
    end
    render json: { error: "You must have at least 15 minutes of coding time logged in Hackatime to create a devlog" }, status: :unprocessable_entity and return if @devlog.duration_seconds < 900

    # save the devlog
    ActiveRecord::Base.transaction do
      if @devlog.save
        Post.create!(project: @project, user: current_api_user, postable: @devlog)
        render :show, status: :created
      else
        render json: { errors: @devlog.errors.full_messages }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end
  rescue StandardError => e
    render json: { error: e }, status: :unprocessable_entity
  end

  def update
    @project = Project.find_by!(id: params[:project_id], deleted_at: nil)
    @devlog = Post::Devlog.joins(:post).find_by!(id: params[:id], posts: { project_id: @project.id })
    previous_body = @devlog.body

    unless @project.memberships.exists?(user: current_api_user)
      render json: { error: "You do not have permission to edit the devlogs for this project" }, status: :forbidden
      return
    end

    if @devlog.update(devlog_params)
      if previous_body != @devlog.body
        @devlog.create_version!(user: current_api_user, previous_body: previous_body)
      end
      render :show
    else
      render json: { errors: @devlog.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Devlog not found" }, status: :not_found
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: e }, status: :unprocessable_entity
  end

  def destroy
    @project = Project.find_by!(id: params[:project_id], deleted_at: nil)
    @devlog = Post::Devlog.joins(:post).find_by!(id: params[:id], posts: { project_id: @project.id })

    unless @project.memberships.exists?(user: current_api_user)
      render json: { error: "You do not have permission to delete devlogs for this project" }, status: :forbidden
      return
    end

    @devlog.soft_delete!
    render json: { message: "Devlog deleted successfully" }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Devlog not found" }, status: :not_found
  rescue StandardError => e
    render json: { error: e }, status: :unprocessable_entity
  end

  private

  def devlog_params
    params.permit(:body)
  end

  def attach_attachments!(devlog, attachments)
    Array(attachments).each do |uploaded|
      unless Post::Devlog::ACCEPTED_CONTENT_TYPES.include?(uploaded.content_type)
        raise ActiveRecord::RecordInvalid.new(devlog), "Invalid attachment content type"
      end
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

      Rails.logger.info "DevlogsController#load_preview_time: project=#{@project.id}, hackatime_keys=#{hackatime_keys.inspect}"

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
  rescue => e
    Rails.logger.error "Failed to load preview time: #{e.message}"
    @preview_seconds = nil
  end
end