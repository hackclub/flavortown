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

    # Issue minimum payout if no payout exists for latest ship
    ship = @project.ship_events.first
    issued_min_payout = false
    if ship.present? && ship.ledger_entries.none?
      hours = ship.hours
      amount = (hours * game_constants.lowerst_dollar_per_hour * game_constants.tickets_per_dollar).round
      if amount > 0
        Payout.create!(amount: amount, payable: ship, user: @project.user, reason: "Minimum payout (shadow banned)", escrowed: false)
        issued_min_payout = true
      end
    end

    @project.shadow_ban!(reason: reason)

    @project.memberships.each do |member|
      next unless member.user&.slack_id.present?

      parts = []
      parts << "Hey! After review, your project won't be going into voting this time."
      parts << "Reason: #{reason}" if reason.present?
      parts << "We issued a minimum payout for your work." if issued_min_payout
      parts << "Keep building – you can ship again anytime!"
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
