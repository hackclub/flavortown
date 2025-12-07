class Project::DevlogsController < ApplicationController
  before_action :set_project
  before_action :require_project_member

  def new
    @devlog = Post::Devlog.new
    load_preview_time
  end

  def create
    @devlog = Post::Devlog.new(devlog_params)
    load_preview_time
    @devlog.duration_seconds = @preview_seconds

    if @devlog.save
      Post.create!(project: @project, user: current_user, postable: @devlog)
      flash[:notice] = "Devlog created successfully"
      current_user.complete_tutorial_step! :post_devlog
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

  def devlog_params
    params.require(:post_devlog).permit(:body, attachments: [])
  end

  def load_preview_time
    @preview_seconds = 0
    return @preview_time = nil unless @project.hackatime_keys.present?
    return @preview_time = nil unless current_user.slack_id.present?

    # Get all projects with their times since event start
    url = "https://hackatime.hackclub.com/api/v1/users/#{current_user.slack_id}/stats?features=projects&start_date=2025-11-05"

    headers = { "RACK_ATTACK_BYPASS" => ENV["HACKATIME_BYPASS_KEYS"] }.compact
    response = Faraday.get(url, nil, headers)

    if response.success?
      data = JSON.parse(response.body)
      projects = data.dig("data", "projects") || []

      # Sum up total_seconds for matching hackatime project keys
      hackatime_keys = @project.hackatime_keys
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
