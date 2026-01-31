class Api::V1::ExternalReportsController < Api::BaseController
  before_action :auth_review_key

  def create
    project = Project.find(params[:project_id])

    existing_report = Project::Report.find_by(project: project, reason: "fraud")
    if existing_report
      render json: serialize(existing_report), status: :ok
      return
    end

    report = Project::Report.new(
      project: project,
      reporter_id: 1734, # avd
      reason: "fraud",
      details: params[:details].presence || "Flagged for fraud review via review.hackclub.com"
    )

    if report.save
      render json: serialize(report), status: :created
    else
      render json: { error: report.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  private

  def auth_review_key
    x = request.headers["Authorization"]&.remove("Bearer ")

    unless x.present? && ActiveSupport::SecurityUtils.secure_compare(x, ENV["REVIEW_REPORT_KEY"].to_s)
      render json: { error: "Unauthorized" }, status: :unauthorized
      false
    end
  end

  def serialize(report)
    {
      id: report.id,
      project_id: report.project_id,
      reason: report.reason,
      status: report.status,
      created_at: report.created_at
    }
  end
end
