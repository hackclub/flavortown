class Project::DevlogsController < ApplicationController
  before_action :set_project

  def new
    @devlog = Post::Devlog.new
    load_preview_time
  end

  def create
    @devlog = Post::Devlog.new(devlog_params)

    if @devlog.save
      Post.create!(project: @project, user: current_user, postable: @devlog)
      @devlog.recalculate_seconds_coded
      flash[:notice] = "Devlog created successfully"
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

  def devlog_params
    params.require(:post_devlog).permit(:body, attachments: [])
  end

  def load_preview_time
    return @preview_time = nil unless @project.hackatime_keys.present?
    return @preview_time = nil unless current_user.slack_id.present?

    project_keys = @project.hackatime_keys.join(",")
    encoded_keys = URI.encode_www_form_component(project_keys)

    # Get total time for these hackatime projects (no date filter for preview)
    url = "https://hackatime.hackclub.com/api/v1/users/#{current_user.slack_id}/stats?" \
          "filter_by_project=#{encoded_keys}&" \
          "features=projects&total_seconds=true"

    headers = { "RACK_ATTACK_BYPASS" => ENV["HACKATIME_BYPASS_KEYS"] }.compact
    response = Faraday.get(url, nil, headers)

    if response.success?
      data = JSON.parse(response.body)
      total_seconds = data.dig("total_seconds").to_i

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
