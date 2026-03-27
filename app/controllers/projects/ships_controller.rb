class Projects::ShipsController < ApplicationController
  before_action :set_project
  before_action :require_shipping_enabled

  def new
    authorize @project, :ship?
    @step = params[:step]&.to_i&.clamp(1, 4) || 1
    @step = 1 if @step > 1 && !@project.shippable?
    load_ship_data
  end

  def create
    authorize @project, :submit_ship?

    # Warn if readme URL is not a raw GitHub URL
    unless @project.readme_is_raw_github_url?
      flash.now[:warning] = "Your README link doesn't appear to be a raw GitHub URL. We require raw README files (from raw.githubusercontent.com) for proper display and consistency. Please update your README URL."
    end

    @project.with_lock do
      @project.submit_for_review!
      @post = @project.posts.create!(user: current_user, postable: Post::ShipEvent.new(body: params[:ship_update].to_s.strip))
      create_sidequest_entries!
    end

    if initial_ship?
      begin
        ShipCertService.ship_to_dash(@project, type: "initial")
        redirect_to @project, notice: "Congratulations! Your project has been submitted for review!"
      rescue => e
        redirect_to @project, alert: "Your project was saved but certification failed: #{e.message}"
      end
    else
      @post.postable.update!(certification_status: "approved")
      redirect_to @project, notice: "Ship submitted! Your project is now out for voting."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: new_project_ships_path(@project), alert: e.record.errors.full_messages.to_sentence
  end

  private

  def set_project = @project = Project.find(params[:project_id])

  def require_shipping_enabled
    unless Flipper.enabled?(:shipping)
      redirect_to @project, alert: "Shipping is currently disabled."
    end
  end
  def initial_ship? = @project.posts.where(postable_type: "Post::ShipEvent").one?

  def load_ship_data
    if @step == 2
      @space_themed_checked = @project.space_themed?
      @project.description = @project.description_without_space_theme_prefix if @project.space_themed?
    end
    @last_ship = @project.last_ship_event
    @devlogs_for_ship = devlogs_since_last_ship
    @active_sidequests = Sidequest.active
  end

  def devlogs_since_last_ship
    devlogs = @project.devlog_posts.includes(:user, postable: [ { attachments_attachments: :blob } ])
    @last_ship ? devlogs.where("posts.created_at > ?", @last_ship.created_at) : devlogs
  end

  def create_sidequest_entries!
    selected_sidequest_id = params[:sidequest_id].to_i

    # Backward compatibility for older clients still posting sidequest_ids[]
    if selected_sidequest_id.zero?
      selected_sidequest_id = Array(params[:sidequest_ids]).map(&:to_i).reject(&:zero?).first.to_i
    end

    if selected_sidequest_id.zero? && @project.space_themed?
      selected_sidequest_id = Sidequest.active.find_by(slug: "challenger")&.id.to_i
    end
    return if selected_sidequest_id.zero?

    active_sidequest_id = Sidequest.active.where(id: selected_sidequest_id).pick(:id)
    return unless active_sidequest_id

    @project.sidequest_entries.find_or_create_by!(sidequest_id: active_sidequest_id)
  end
end
