class Admin::ShipCertificationsController < Admin::ApplicationController
  before_action :set_project
  before_action :ensure_reviewable_state, only: [ :show, :start_review, :approve, :reject ]

  def index
    authorize :admin, :manage_projects?

    @category = params[:category] || "all_pending"
    @pagy, @projects = pagy(:offset, sorted_projects(filtered_projects(@category)))
    generate_statistics
    generate_leaderboards
  end

  private

  def project_type_filters
    {
      "web" => "web",
      "mobile" => "mobile",
      "game" => "game",
      "hardware" => "hardware",
      "cli" => "cli",
      "other" => [ "desktop", "other", nil ]
    }
  end

  def base_pending_scope(include_associations: false)
    scope = Project.where(ship_status: %w[submitted under_review])

    if include_associations
      scope = scope.includes(:users, :latest_ship_certification, banner_attachment: :blob)
                   .order(shipped_at: :asc)
    end

    scope
  end

  def sorted_projects(scope)
    case params[:sort]
    when "shipped_desc"
      scope.reorder(shipped_at: :desc)
    when "time_desc"
      scope.left_joins(:posts)
           .where(posts: { postable_type: "Post::Devlog" })
           .left_joins("LEFT JOIN post_devlogs ON post_devlogs.id = posts.postable_id::bigint")
           .group("projects.id")
           .reorder(Arel.sql("COALESCE(SUM(post_devlogs.duration_seconds), 0) DESC"))
    when "time_asc"
      scope.left_joins(:posts)
           .where(posts: { postable_type: "Post::Devlog" })
           .left_joins("LEFT JOIN post_devlogs ON post_devlogs.id = posts.postable_id::bigint")
           .group("projects.id")
           .reorder(Arel.sql("COALESCE(SUM(post_devlogs.duration_seconds), 0) ASC"))
    when "random"
      scope.reorder(Arel.sql("RANDOM()"))
    else
      scope.reorder(shipped_at: :asc)
    end
  end

  def filtered_projects(category)
    case category
    when "all_pending"
      base_pending_scope(include_associations: true)
    when "submitted"
      base_pending_scope(include_associations: true).where(ship_status: "submitted")
    when "under_review"
      base_pending_scope(include_associations: true).where(ship_status: "under_review")
    when "approved"
      Project.where(ship_status: "approved")
             .includes(:users, :latest_ship_certification, banner_attachment: :blob)
             .order(updated_at: :desc)
    when "rejected"
      Project.where(ship_status: "rejected")
             .includes(:users, :latest_ship_certification, banner_attachment: :blob)
             .order(updated_at: :desc)
    else
      if project_type_filters.key?(category)
        base_pending_scope(include_associations: true)
          .where(project_type: project_type_filters[category])
      else
        base_pending_scope(include_associations: true)
      end
    end
  end

  def generate_statistics
    base_projects = base_pending_scope

    @stats = {
      all_pending: generate_category_stats(base_projects),
      submitted: generate_category_stats(base_projects.where(ship_status: "submitted")),
      under_review: generate_category_stats(base_projects.where(ship_status: "under_review")),
      approved: { count: Project.where(ship_status: "approved").count },
      rejected: { count: Project.where(ship_status: "rejected").count }
    }

    project_type_filters.each do |type, filter_value|
      @stats[type.to_sym] = generate_category_stats(base_projects.where(project_type: filter_value))
    end
  end

  def generate_category_stats(scope)
    count = scope.count
    avg_wait_seconds = scope.where.not(shipped_at: nil)
                            .average("EXTRACT(EPOCH FROM (NOW() - shipped_at))")&.to_i || 0

    {
      count: count,
      avg_wait: avg_wait_seconds
    }
  end

  def generate_leaderboards
    est_zone = ActiveSupport::TimeZone.new("America/New_York")
    current_est = Time.current.in_time_zone(est_zone)
    week_start = current_est.beginning_of_week(:sunday)

    @leaderboard_week = reviewer_leaderboard(since: week_start)
    @leaderboard_day = reviewer_leaderboard(since: 24.hours.ago)
    @leaderboard_all = reviewer_leaderboard(since: nil)
  end

  def reviewer_leaderboard(since: nil)
    scope = ShipCertification
      .joins(:reviewer)
      .where.not(reviewer_id: nil)
      .where.not(aasm_state: "pending")
      .group("users.id", "users.display_name", "users.email")
      .order("COUNT(ship_certifications.id) DESC")
      .limit(20)

    scope = scope.where("ship_certifications.decided_at >= ?", since) if since.present?

    scope.pluck("users.display_name", "users.email", "COUNT(ship_certifications.id)")
  end

  public

  def show
    authorize :admin, :manage_projects?

    @ship_certification = @project.latest_ship_certification ||
                          @project.ship_certifications.build
  end

  def start_review
    authorize :admin, :manage_projects?

    PaperTrail.request(whodunnit: current_user.id) do
      if @project.may_start_review?
        @project.start_review!
      end

      @ship_certification = @project.latest_ship_certification ||
                            @project.ship_certifications.create!(reviewer: current_user)

      @ship_certification.update!(reviewer: current_user) if @ship_certification.reviewer.nil?
    end

    redirect_to admin_project_ship_certification_path(@project),
                notice: "Review started. You are now assigned as the reviewer."
  end

  def approve
    authorize :admin, :manage_projects?

    feedback = params[:feedback].to_s

    PaperTrail.request(whodunnit: current_user.id) do
      @ship_certification = load_or_create_certification

      old_state = @ship_certification.aasm_state
      old_feedback = @ship_certification.feedback

      @ship_certification.feedback = feedback
      @ship_certification.reviewer = current_user
      @ship_certification.approve

      ActiveRecord::Base.transaction do
        @ship_certification.save!

        @project.start_review! if @project.may_start_review?
        @project.approve! if @project.may_approve?

        PaperTrail::Version.create!(
          item_type: "ShipCertification",
          item_id: @ship_certification.id,
          event: "approve",
          whodunnit: current_user.id,
          object_changes: {
            aasm_state: [ old_state, @ship_certification.aasm_state ],
            feedback: [ old_feedback, @ship_certification.feedback ]
          }.to_yaml
        )
      end
    end

    redirect_to admin_ship_certifications_path, notice: "Project approved successfully!"
  rescue AASM::InvalidTransition, ActiveRecord::RecordInvalid => e
    redirect_to admin_project_ship_certification_path(@project),
                alert: "Failed to approve: #{e.message}"
  end

  def reject
    authorize :admin, :manage_projects?

    feedback = params[:feedback].presence || "No feedback provided"

    PaperTrail.request(whodunnit: current_user.id) do
      @ship_certification = load_or_create_certification

      old_state = @ship_certification.aasm_state
      old_feedback = @ship_certification.feedback

      @ship_certification.feedback = feedback
      @ship_certification.reviewer = current_user
      @ship_certification.reject

      ActiveRecord::Base.transaction do
        @ship_certification.save!

        @project.start_review! if @project.may_start_review?
        @project.reject! if @project.may_reject?

        PaperTrail::Version.create!(
          item_type: "ShipCertification",
          item_id: @ship_certification.id,
          event: "reject",
          whodunnit: current_user.id,
          object_changes: {
            aasm_state: [ old_state, @ship_certification.aasm_state ],
            feedback: [ old_feedback, @ship_certification.feedback ]
          }.to_yaml
        )
      end
    end

    redirect_to admin_ship_certifications_path, notice: "Project rejected."
  rescue AASM::InvalidTransition, ActiveRecord::RecordInvalid => e
    redirect_to admin_project_ship_certification_path(@project),
                alert: "Failed to reject: #{e.message}"
  end

  private

  def set_project
    @project = Project.find(params[:project_id]) if params[:project_id].present?
  end

  def ensure_reviewable_state
    return if @project.nil?

    unless @project.ship_status.in?(%w[submitted under_review])
      redirect_to admin_ship_certifications_path,
                  alert: "Project is not in a reviewable state (current: #{@project.ship_status})."
    end
  end

  def load_or_create_certification
    @project.latest_ship_certification ||
      @project.ship_certifications.create!(reviewer: current_user)
  end
end
