class Admin::ProjectsController < Admin::ApplicationController
  def index
    authorize :admin, :manage_projects?
    @query = params[:query]
    @filter = params[:filter] || "active"

    projects = case @filter
    when "deleted"
      Project.unscoped.deleted
    when "all"
      Project.unscoped.all
    else
      Project.all
    end

    if @query.present?
      q = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      projects = projects.where("title ILIKE ? OR description ILIKE ?", q, q)
    end

    @pagy, @projects = pagy(:offset, projects.order(:id))
  end

  def show
    authorize :admin, :manage_projects?
    @project = Project.unscoped.find(params[:id])
  end

  def votes
    authorize :admin, :manage_projects?
    @project = Project.find(params[:id])

    @pagy, @votes = pagy(
      @project.votes.includes(:user).order(created_at: :desc)
    )
  end

  def restore
    authorize :admin, :manage_projects?
    @project = Project.unscoped.find(params[:id])

    if @project.deleted?
      @project.restore!
      redirect_to admin_project_path(@project), notice: "Project restored successfully."
    else
      redirect_to admin_project_path(@project), alert: "Project is not deleted."
    end
  end

  def delete
    authorize :admin, :manage_projects?
    @project = Project.unscoped.find(params[:id])

    if @project.deleted?
      redirect_to admin_project_path(@project), alert: "Project is already deleted."
    else
      @project.soft_delete!(force: true)
      redirect_to admin_project_path(@project), notice: "Project deleted successfully."
    end
  end

  def shadow_ban
    authorize :admin, :shadow_ban_projects?
    @project = Project.unscoped.find(params[:id])

    reason = params[:reason].presence
    issued_min_payout = false

    ActiveRecord::Base.transaction do
      # Issue minimum payout if no payout exists for latest ship
      ship = @project.ship_events.order(:created_at).last
      if ship.present? && ship.payout.blank?
        hours = ship.hours
        game_constants = Rails.configuration.game_constants
        min_multiplier = game_constants.sb_min_dollar_per_hour.to_f
        amount = (min_multiplier * hours).ceil
        payout_user = @project.memberships.owner.first&.user
        if amount > 0 && payout_user
          payout_user.ledger_entries.create!(
            amount: amount, reason: "Ship Event Payout: #{@project.title}", created_by: "System", ledgerable: payout_user
          )
          issued_min_payout = true
        end
      end

      @project.shadow_ban!(reason: reason)
    end
    # Resolve all pending reports on the project
    @project.reports.pending.update_all(
      status: Project::Report.statuses[:reviewed],
      updated_at: Time.current
    )

    @project.memberships.each do |member|
      next unless member.user&.slack_id.present?

      parts = []
      parts << "Hey! After review, your project won't be going into voting this time."
      parts << "Reason: #{reason}" if reason.present?
      parts << "We've issued a minimum payout for your work on this ship." if issued_min_payout
      parts << "If you have questions, reach out in #flavortown-help. Keep building – you can ship again anytime!"
      SendSlackDmJob.perform_later(member.user.slack_id, parts.join("\n\n"))
    end

    log_to_user_audit(@project, "shadow_banned", reason)

    redirect_to admin_project_path(@project), notice: "Project has been shadow banned#{issued_min_payout ? ' and minimum payout issued' : ''}."
  end

  def unshadow_ban
    authorize :admin, :shadow_ban_projects?
    @project = Project.unscoped.find(params[:id])

    @project.unshadow_ban!

    log_to_user_audit(@project, "unshadow_banned", nil)

    redirect_to admin_project_path(@project), notice: "Project shadow ban has been removed."
  end

  private

  def log_to_user_audit(project, action, reason)
    project.users.each do |user|
      PaperTrail::Version.create!(
        item_type: "User",
        item_id: user.id,
        event: "update",
        whodunnit: current_user.id.to_s,
        object_changes: {
          project_shadow_ban: [ action, { project_id: project.id, project_title: project.title, reason: reason } ]
        }
      )
    end
  end
end
