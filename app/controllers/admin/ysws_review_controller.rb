module Admin
  class YswsReviewController < Admin::ApplicationController
    before_action :set_project, only: [ :show, :update, :return_to_certifier ]

    def index
      authorize :admin, :access_ysws_reviews?

      @projects = Project.includes(:users, :devlogs, :ysws_review_submission)
                         .where.not(ship_status: "draft")
                         .order("RANDOM()")
                         .limit(50)

      @stats = {
        total: Project.where.not(ship_status: "draft").count,
        pending: YswsReview::Submission.pending_review.count,
        reviewed: YswsReview::Submission.reviewed.count
      }

      @leaderboard = calculate_reviewer_leaderboard
    end

    def show
      authorize :admin, :access_ysws_reviews?

      @submission = @project.ysws_review_submission ||
                    @project.build_ysws_review_submission(status: :pending)

      @devlogs = load_devlogs_with_approvals
      @ship_events = @project.ship_posts.includes(:postable)
    end

    def update
      authorize :admin, :access_ysws_reviews?

      @submission = @project.ysws_review_submission ||
                    @project.create_ysws_review_submission!(status: :pending)

      ActiveRecord::Base.transaction do
        process_devlog_approvals
        @submission.mark_reviewed!(reviewer: current_user, status: :approved)
      end

      YswsReview::SyncSubmissionJob.perform_later(@submission.id)

      redirect_to admin_ysws_reviews_path, notice: "Review completed successfully"
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_ysws_review_path(@project), alert: "Error saving review: #{e.message}"
    end

    def return_to_certifier
      authorize :admin, :access_ysws_reviews?

      reasons = params[:feedback_reasons]&.reject(&:blank?) || []

      if reasons.empty?
        redirect_to admin_ysws_review_path(@project), alert: "Please select at least one feedback reason"
        return
      end

      latest_certification = @project.ship_certifications.order(created_at: :desc).first

      if latest_certification
        latest_certification.return_to_certifier!(user: current_user, reasons: reasons)
        redirect_to admin_ysws_reviews_path, notice: "Project returned to ship certifier"
      else
        redirect_to admin_ysws_review_path(@project), alert: "No ship certification found"
      end
    end

    private

    def set_project
      @project = Project.find(params[:id])
    end

    def load_devlogs_with_approvals
      devlog_posts = @project.devlogs.includes(postable: :attachments_attachments)
                             .order(created_at: :asc)

      devlog_posts.map do |post|
        devlog = post.postable
        approval = find_or_build_approval(devlog)

        {
          post: post,
          devlog: devlog,
          approval: approval
        }
      end
    end

    def find_or_build_approval(devlog)
      return nil unless @submission.persisted?

      @submission.devlog_approvals.find_by(post_devlog_id: devlog.id) ||
        @submission.devlog_approvals.build(
          post_devlog: devlog,
          original_seconds: devlog.duration_seconds || 0,
          approved_seconds: devlog.duration_seconds || 0,
          approved: false
        )
    end

    def process_devlog_approvals
      return unless params[:devlog_approvals].present?

      params[:devlog_approvals].each do |devlog_id, approval_params|
        devlog = Post::Devlog.find(devlog_id)

        approval = @submission.devlog_approvals.find_or_initialize_by(post_devlog: devlog)
        approval.update!(
          reviewer: current_user,
          approved: approval_params[:approved] == "1",
          approved_seconds: (approval_params[:approved_minutes].to_i * 60),
          original_seconds: devlog.duration_seconds || 0,
          internal_notes: approval_params[:internal_notes],
          reviewed_at: Time.current
        )
      end
    end

    def calculate_reviewer_leaderboard
      YswsReview::Submission
        .where.not(reviewer_id: nil)
        .group(:reviewer_id)
        .order("count_all DESC")
        .limit(10)
        .count
        .map do |user_id, count|
          user = User.find_by(id: user_id)
          { user: user, count: count } if user
        end.compact
    end
  end
end
