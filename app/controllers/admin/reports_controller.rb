module Admin
  class ReportsController < Admin::ApplicationController
    before_action :set_report, only: [ :show, :review, :dismiss ]

    def index
      authorize :admin, :access_reports?

      @reports = Report.includes(:reporter, :project).order(created_at: :desc)

      @reports = @reports.where(status: params[:status]) if params[:status].present?
      @reports = @reports.where(reason: params[:reason]) if params[:reason].present?

      @counts = {
        pending: Report.pending.count,
        reviewed: Report.reviewed.count,
        dismissed: Report.dismissed.count
      }
    end

    def show
      authorize :admin, :access_reports?
    end

    def review
      authorize :admin, :access_reports?
      update_status(:reviewed, "Report marked as reviewed")
    end

    def dismiss
      authorize :admin, :access_reports?
      update_status(:dismissed, "Report dismissed")
    end

    private

    def set_report
      @report = Report.find(params[:id])
    end

    def update_status(new_status, notice_message)
      old_status = @report.status

      if @report.update(status: new_status)
        PaperTrail::Version.create!(
          item_type: "Report",
          item_id: @report.id,
          event: "update",
          whodunnit: current_user.id,
          object_changes: {
            status: [ old_status, @report.status ]
          }.to_yaml
        )
        redirect_to admin_reports_path, notice: notice_message
      else
        redirect_to admin_report_path(@report), alert: "Failed to update report"
      end
    end
  end
end
