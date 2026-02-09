class Api::V1::ExternalReportsController < Api::BaseController
  skip_forgery_protection
  before_action :auth_review_key

  def create
    project = Project.find_by(id: params[:project_id])
    unless project
      render json: { error: "Project not found" }, status: :not_found
      return
    end

    reported_by = params[:reported_by].presence || params[:reportedBy].presence
    reason = params[:reason].presence || "External flag"
    reporter_id = normalize_reporter_id(reported_by)

    existing_report = Project::Report.find_by(project: project, reason: reason)
    if existing_report
      render json: serialize(existing_report), status: :ok
      return
    end

    report = Project::Report.new(
      project: project,
      reporter_id: reporter_id,
      reason: reason,
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

  def normalize_reporter_id(reported_by)
    return 1734 if reported_by.blank?

    Integer(reported_by, 10)
  rescue ArgumentError, TypeError
    1734
  end
end
