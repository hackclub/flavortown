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
    @token = Report::ReviewToken.pending.find_by(token: params[:token])

    unless @token
      return redirect_to root_path, alert: "Invalid or expired review token"
    end

    unless @token.action.to_s == action_name.to_s
      redirect_to root_path, alert: "Invalid review token action"
    end
  end

  def process_token(new_status)
    Report::ReviewToken.transaction do
      # Lock the token row to ensure only one concurrent consumer
      @token.lock!

      # Re-check validity under the lock to prevent race conditions
      unless @token&.valid?
        redirect_to root_path, alert: "Invalid or expired review token"
        raise ActiveRecord::Rollback
      end

      report = @token.report
      old_status = report.status

      if report.update(status: new_status) && @token.update(used_at: Time.current)
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
        raise ActiveRecord::Rollback
      end
    end
  end
end
