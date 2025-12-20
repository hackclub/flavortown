# == Schema Information
#
# Table name: reports
#
#  id          :bigint           not null, primary key
#  details     :text             not null
#  reason      :string           not null
#  status      :integer          default("pending"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  project_id  :bigint           not null
#  reporter_id :bigint           not null
#
# Indexes
#
#  index_reports_on_project_id                  (project_id)
#  index_reports_on_reporter_id                 (reporter_id)
#  index_reports_on_reporter_id_and_project_id  (reporter_id,project_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (reporter_id => users.id)
#
class Report < ApplicationRecord
  belongs_to :reporter, class_name: "User"
  belongs_to :project
  after_create :share_with_channel

  REASONS = %w[low_effort undeclared_ai demo_broken other].freeze

  enum :status, { pending: 0, reviewed: 1, dismissed: 2 }, default: :pending

  validates :reason, presence: true, inclusion: { in: REASONS }
  validates :details, presence: true, length: { minimum: 20 }
  validates :reporter_id, uniqueness: { scope: :project_id, message: "has already reported this project" }

  validate :reporter_cannot_report_own_project, unless: -> { Rails.env.development? }

  private

  def reporter_cannot_report_own_project
    errors.add(:reporter, "cannot report own project") if project&.users&.exists?(reporter_id)
  end
  def share_with_channel
    SendSlackDmJob.perform_later("C0A1YJ9PDAS", "New report received", blocks_path: "notifications/reports/slack_message", locals: { report: self })
  end
end
