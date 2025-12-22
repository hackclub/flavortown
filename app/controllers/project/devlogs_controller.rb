class Project::DevlogsController < ApplicationController
  before_action :set_project
  before_action :require_project_member
  before_action :require_hackatime_project
  before_action :sync_hackatime_projects
  before_action :load_preview_time
  before_action :require_preview_time

  def new
    @devlog = Post::Devlog.new
  end

  def create
    @devlog = Post::Devlog.new(devlog_params)
    @devlog.duration_seconds = @preview_seconds
    @devlog.hackatime_projects_key_snapshot = @project.hackatime_keys.join(",")

    if @devlog.save
      Post.create!(project: @project, user: current_user, postable: @devlog)
      flash[:notice] = "Devlog created successfully"

      unless @devlog.tutorial?
        FunnelTrackerService.track(
          event_name: "devlog_created",
          user: current_user,
          properties: { devlog_id: @devlog.id, project_id: @project.id }
        )
      end

      if current_user.complete_tutorial_step! :post_devlog
        tutorial_message [
          "Yay! You just earned free stickers for posting your first devlog — claim them from the Kitchen!",
          "Now ship your project (when it is cooked to your satisfaction) to earn cookies 🍪 and exchange those for stuff in the shop.",
          "Bonne chance! Remember, anyone can cook — go forth and whip up a storm!"
        ]
      end

      redirect_to @project
    else
      flash.now[:alert] = @devlog.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def require_project_member
    unless current_user && @project.users.include?(current_user)
      redirect_to @project, alert: "You must be a project member to add devlogs" and return
    end
  end

  def require_hackatime_project
    unless @project.hackatime_keys.present?
      redirect_to edit_project_path(@project), alert: "You must link at least one Hackatime project before posting a devlog" and return
    end
  end

  def sync_hackatime_projects
    owner = @project.memberships.owner.first&.user
    return unless owner

    owner.try_sync_hackatime_data!
    @project.reload
  end

  def require_preview_time
    unless @preview_time.present?
      @retry_count = (params[:retry] || 0).to_i
      if @retry_count < 3
        @show_loading = true
        render :loading and return
      else
        redirect_to @project, alert: "Could not fetch your coding time from Hackatime after multiple attempts. Please ensure Hackatime is tracking your project." and return
      end
    end
  end

  def devlog_params
    params.require(:post_devlog).permit(:body, :scrapbook_url, attachments: [])
  end

  def load_preview_time
    @preview_seconds = 0
    @project.reload
    hackatime_keys = @project.hackatime_keys

    Rails.logger.info "DevlogsController#load_preview_time: project=#{@project.id}, hackatime_keys=#{hackatime_keys.inspect}"

    return @preview_time = nil unless hackatime_keys.present?

    result = current_user.try_sync_hackatime_data!
    return @preview_time = nil unless result

    project_times = result[:projects]
    total_seconds = hackatime_keys.sum { |key| project_times[key].to_i }

    already_logged = Post::Devlog.where(
      id: @project.posts.where(postable_type: "Post::Devlog").select("postable_id::bigint")
    ).sum(:duration_seconds) || 0

    @preview_seconds = [ total_seconds - already_logged, 0 ].max
    hours = @preview_seconds / 3600
    minutes = (@preview_seconds % 3600) / 60
    @preview_time = "#{hours}h #{minutes}m"
  rescue => e
    Rails.logger.error "Failed to load preview time: #{e.message}"
    @preview_time = nil
  end
end
