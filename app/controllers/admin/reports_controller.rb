module Admin
  class ReportsController < Admin::ApplicationController
    before_action :set_report, only: [ :show, :review, :dismiss ]

    def index
      authorize :admin, :access_reports?

      @reports = Project::Report.includes(:reporter, :project).order(created_at: :desc)

      @reports = @reports.where(status: params[:status]) if params[:status].present?
      @reports = @reports.where(reason: params[:reason]) if params[:reason].present?

      @counts = {
        pending: Project::Report.pending.count,
        reviewed: Project::Report.reviewed.count,
        dismissed: Project::Report.dismissed.count
      }

      report_ids = @reports.map { |r| r.id.to_s }
      latest_versions = PaperTrail::Version
        .where(item_type: "Project::Report", item_id: report_ids)
        .where("object_changes ? 'status'")
        .order(:item_id, created_at: :desc)
        .select("DISTINCT ON (item_id) *")

      reviewer_ids = latest_versions.map(&:whodunnit).compact.uniq
      reviewers_by_id = User.where(id: reviewer_ids).index_by(&:id)

      @reviewers_by_report = latest_versions.each_with_object({}) do |version, hash|
        if version.whodunnit.present?
          hash[version.item_id.to_i] = reviewers_by_id[version.whodunnit.to_i]
        elsif version.object_changes.is_a?(Hash) && version.object_changes["auto_processed"].present?
          hash[version.item_id.to_i] = :auto
        end
      end
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

    def process_demo_broken
      authorize :admin, :access_reports?
      ProcessDemoBrokenReportsJob.perform_later
      redirect_to admin_reports_path, notice: "Demo broken reports processing job has been queued"
    end

    private

    def set_report
      @report = Project::Report.find(params[:id])
    end

    def update_status(new_status, notice_message)
      old_status = @report.status

      if @report.update(status: new_status)
        PaperTrail::Version.create!(
          item_type: "Project::Report",
          item_id: @report.id,
          event: "update",
          whodunnit: current_user.id.to_s,
          object_changes: {
            status: [ old_status, @report.status ]
          }
        )
        redirect_to admin_reports_path, notice: notice_message
      else
        redirect_to admin_report_path(@report), alert: "Failed to update report"
      end
    end
  end
end
