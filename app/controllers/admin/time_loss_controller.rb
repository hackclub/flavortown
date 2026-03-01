class Admin::TimeLossController < Admin::ApplicationController
  def index
    authorize :admin, :access_admin_endpoints?

    audits = HackatimeTimeLossAudit.includes(:project, :user).order(difference_seconds: :desc)

    @total_inflation = audits.where("difference_seconds > 0").sum(:difference_seconds)
    @total_deflation = audits.where("difference_seconds < 0").sum(:difference_seconds)
    @total_projects = audits.count
    @last_audited_at = audits.maximum(:audited_at)

    filter = params[:filter]
    if filter == "inflation"
      audits = audits.where("difference_seconds > 0")
    elsif filter == "deflation"
      audits = audits.where("difference_seconds < 0")
    end

    @pagy, @audits = pagy(:offset, audits)
  end
end
