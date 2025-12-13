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

      if current_user.complete_tutorial_step! :post_devlog
        tutorial_message [
          "Yay! Chef, you just earned free stickers for posting your first devlog!",
          "Now ship your project (when it is cooked to your satisfaction) to earn cookies 🍪 and exchange those for stuff in the shop.",
          "Bonne chance chef! Remember, anyone can cook — go forth and whip up a storm!"
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

    hackatime_identity = owner.identities.find_by(provider: "hackatime")
    return unless hackatime_identity

    HackatimeService.sync_user_projects(owner, hackatime_identity.uid)
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

    Rails.logger.info "DevlogsController#load_preview_time: project=#{@project.id}, hackatime_keys=#{hackatime_keys.inspect}, slack_id=#{current_user.slack_id}"

    return @preview_time = nil unless hackatime_keys.present?
    return @preview_time = nil unless current_user.slack_id.present?

    # Get all projects with their times since event start
    url = "https://hackatime.hackclub.com/api/v1/users/#{current_user.slack_id}/stats?features=projects&start_date=2025-11-05"

    headers = { "RACK_ATTACK_BYPASS" => ENV["HACKATIME_BYPASS_KEYS"] }.compact
    response = Faraday.get(url, nil, headers)

    if response.success?
      data = JSON.parse(response.body)
      projects = data.dig("data", "projects") || []

      # Sum up total_seconds for matching hackatime project keys
      total_seconds = projects
        .select { |p| hackatime_keys.include?(p["name"]) }
        .sum { |p| p["total_seconds"].to_i }

      # Subtract time already logged in previous devlogs
      already_logged = Post::Devlog.where(
        id: @project.posts.where(postable_type: "Post::Devlog").select("postable_id::bigint")
      ).sum(:duration_seconds) || 0

      @preview_seconds = [ total_seconds - already_logged, 0 ].max
      hours = @preview_seconds / 3600
      minutes = (@preview_seconds % 3600) / 60
      @preview_time = "#{hours}h #{minutes}m"
    else
      @preview_time = nil
    end
  rescue => e
    Rails.logger.error "Failed to load preview time: #{e.message}"
    @preview_time = nil
  end
end
