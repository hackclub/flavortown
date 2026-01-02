# == Schema Information
#
# Table name: ysws_review_submissions
#
#  id          :bigint           not null, primary key
#  reviewed_at :datetime
#  status      :integer          default("pending"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  project_id  :bigint           not null
#  reviewer_id :bigint
#
# Indexes
#
#  index_ysws_review_submissions_on_project_id   (project_id) UNIQUE
#  index_ysws_review_submissions_on_reviewer_id  (reviewer_id)
#
module YswsReview
  class Submission < ApplicationRecord
    self.table_name = "ysws_review_submissions"

    belongs_to :project
    belongs_to :reviewer, class_name: "User", optional: true

    has_many :devlog_approvals, class_name: "YswsReviewDevlogApproval",
             foreign_key: :ysws_review_submission_id, dependent: :destroy

    enum :status, { pending: 0, approved: 1, rejected: 2 }

    has_paper_trail

    scope :reviewed, -> { where.not(status: :pending) }
    scope :pending_review, -> { where(status: :pending) }

    def reviewed?
      approved? || rejected?
    end

    def mark_reviewed!(reviewer:, status:)
      update!(
        reviewer: reviewer,
        status: status,
        reviewed_at: Time.current
      )
    end

    def total_approved_seconds
      devlog_approvals.where(approved: true).sum(:approved_seconds)
    end

    def total_original_seconds
      devlog_approvals.sum(:original_seconds)
    end
  end
end
