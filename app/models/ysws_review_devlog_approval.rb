# == Schema Information
#
# Table name: ysws_review_devlog_approvals
#
#  id                        :bigint           not null, primary key
#  approved                  :boolean          default(FALSE), not null
#  approved_seconds          :integer          default(0), not null
#  internal_notes            :text
#  original_seconds          :integer          default(0), not null
#  reviewed_at               :datetime
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  post_devlog_id            :bigint           not null
#  reviewer_id               :bigint
#  ysws_review_submission_id :bigint           not null
#
# Indexes
#
#  idx_on_ysws_review_submission_id_8b0db5beb0           (ysws_review_submission_id)
#  idx_ysws_devlog_approvals_unique                      (ysws_review_submission_id,post_devlog_id) UNIQUE
#  index_ysws_review_devlog_approvals_on_post_devlog_id  (post_devlog_id)
#  index_ysws_review_devlog_approvals_on_reviewer_id     (reviewer_id)
#
# Foreign Keys
#
#  fk_rails_...  (ysws_review_submission_id => ysws_review_submissions.id)
#
class YswsReviewDevlogApproval < ApplicationRecord
  belongs_to :ysws_review_submission, class_name: "YswsReview::Submission"
  belongs_to :post_devlog, class_name: "Post::Devlog"
  belongs_to :reviewer, class_name: "User", optional: true

  has_paper_trail

  validates :post_devlog_id, uniqueness: { scope: :ysws_review_submission_id }

  scope :approved, -> { where(approved: true) }
  scope :rejected, -> { where(approved: false) }

  def time_changed?
    approved_seconds != original_seconds
  end

  def approved_minutes
    approved_seconds / 60
  end

  def original_minutes
    original_seconds / 60
  end
end
