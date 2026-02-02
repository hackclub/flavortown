class Projects::ShipsController < ApplicationController
  before_action :set_project

  def new
    authorize @project, :ship?
    @step = params[:step]&.to_i&.clamp(1, 4) || 1
    @step = 1 if @step > 1 && !@project.shippable?
    load_ship_data
  end

  def create
    authorize @project, :submit_ship?

    @project.with_lock do
      @project.submit_for_review!
      @post = @project.posts.create!(user: current_user, postable: Post::ShipEvent.new(body: params[:ship_update].to_s.strip))
    end

    if initial_ship?
      ShipCertWebhookJob.perform_later(ship_event_id: @post.postable_id, type: "initial", force: false)
      redirect_to @project, notice: "Congratulations! Your project has been submitted for review!"
    else
      @post.postable.update!(certification_status: "approved")
      redirect_to @project, notice: "Ship submitted! Your project is now out for voting."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: new_project_ships_path(@project), alert: e.record.errors.full_messages.to_sentence
  end

  private

  def set_project = @project = Project.find(params[:project_id])
  def initial_ship? = @project.posts.where(postable_type: "Post::ShipEvent").one?

  def load_ship_data
    @hackatime_projects = @project.hackatime_projects_with_time
    @total_hours = @project.total_hackatime_hours
    @last_ship = @project.last_ship_event
    @devlogs_for_ship = devlogs_since_last_ship
  end

  def devlogs_since_last_ship
    devlogs = @project.devlog_posts.includes(:user, postable: [ { attachments_attachments: :blob } ])
    @last_ship ? devlogs.where("posts.created_at > ?", @last_ship.created_at) : devlogs
  end
end
