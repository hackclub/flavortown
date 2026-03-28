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
    selected_sidequest = selected_sidequest_for_submission

    # Warn if readme URL is not a raw GitHub URL
    unless @project.readme_is_raw_github_url?
      flash.now[:warning] = "Your README link doesn't appear to be a raw GitHub URL. We require raw GitHub files (from raw.githubusercontent.com) for proper display and consistency. Please update your README URL."
    end

    @project.with_lock do
      apply_space_theme_for_sidequest!(selected_sidequest)

      unless @project.submit_for_review
        raise ActiveRecord::RecordInvalid.new(@project) if @project.errors.any?
        raise StandardError, "Project cannot be shipped. Please check all requirements on step 1."
      end

      ship_event = Post::ShipEvent.new(
        body: params[:ship_update].to_s.strip,
        review_instructions: params[:review_instructions].to_s.strip.presence
      )

      raise ActiveRecord::RecordInvalid.new(ship_event) unless ship_event.valid?

      ship_period_seconds = @project.send(:duration_seconds_since_last_ship)
      raise StandardError, "Cannot ship with 0 hours — log some devlog time first." if ship_period_seconds <= 0

      @post = @project.posts.create!(user: current_user, postable: ship_event)
      create_sidequest_entries!(selected_sidequest)
    end

    if initial_ship?
      ShipCertWebhookJob.perform_later(ship_event_id: @post.postable.id, type: "initial")
      redirect_to @project, notice: "Congratulations! Your project has been submitted for review!"
    else
      @post.postable.update!(certification_status: "approved")
      redirect_to @project, notice: "Ship submitted! Your project is now out for voting."
    end
  rescue Pundit::NotAuthorizedError
    redirect_to @project, alert: "You're not eligible to ship yet. Make sure your identity is verified and your account is YSWS eligible."
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: new_project_ships_path(@project), alert: e.record.errors.full_messages.to_sentence
  rescue StandardError => e
    redirect_back fallback_location: new_project_ships_path(@project), alert: e.message
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
    @last_ship = @project.last_ship_event
    @devlogs_for_ship = devlogs_since_last_ship
    @active_sidequests = Sidequest.active
  end

  def devlogs_since_last_ship
    devlogs = @project.devlog_posts.includes(:user, postable: [ { attachments_attachments: :blob } ])
    @last_ship ? devlogs.where("posts.created_at > ?", @last_ship.created_at) : devlogs
  end

  def selected_sidequest_for_submission
    selected_sidequest_id = params[:sidequest_id].to_i

    # Backward compatibility for older clients still posting sidequest_ids[]
    if selected_sidequest_id.zero?
      selected_sidequest_id = Array(params[:sidequest_ids]).map(&:to_i).reject(&:zero?).first.to_i
    end
    return nil if selected_sidequest_id.zero?

    Sidequest.active.find_by(id: selected_sidequest_id)
  end

  def create_sidequest_entries!(selected_sidequest)
    return unless selected_sidequest

    @project.sidequest_entries.find_or_create_by!(sidequest_id: selected_sidequest.id)
  end

  def apply_space_theme_for_sidequest!(selected_sidequest)
    base_description = @project.description_without_space_theme_prefix
    @project.description = if selected_sidequest&.slug == "challenger"
      [ Project::SPACE_THEMED_PREFIX, base_description.presence ].compact.join(" ")
    else
      base_description
    end
  end
end
