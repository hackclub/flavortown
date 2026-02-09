class ReportReviewsController < ApplicationController
  before_action :ensure_logged_in
  before_action :find_token, only: [ :review, :dismiss ]

  def review
    process_token(:reviewed)
  end

  def dismiss
    process_token(:dismissed)
  end

  private

  def ensure_logged_in
    redirect_to "/?login=1", alert: "You must be logged in to review reports" unless current_user
  end

  def find_token
    @token = Report::ReviewToken.find_by(token: params[:token])
    unless @token&.valid?
      redirect_to root_path, alert: "Invalid or expired review token"
    end
  end

  def process_token(new_status)
    report = @token.report
    old_status = report.status

    if report.update(status: new_status)
      @token.update(used_at: Time.current)

      PaperTrail::Version.create!(
        item_type: "Project::Report",
        item_id: report.id,
        event: "update",
        whodunnit: current_user.id.to_s,
        object_changes: {
          status: [ old_status, @token.report.status ]
        }
      )

      action_text = new_status == 1 ? "reviewed" : "dismissed"
      redirect_to root_path, notice: "Report has been #{action_text}"
    else
      redirect_to root_path, alert: "Failed to process report"
    end
  end
end
