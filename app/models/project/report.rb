# == Schema Information
#
# Table name: project_reports
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
#  idx_project_reports_status_created_at_desc           (status,created_at DESC)
#  index_project_reports_on_project_id                  (project_id)
#  index_project_reports_on_reporter_id                 (reporter_id)
#  index_project_reports_on_reporter_id_and_project_id  (reporter_id,project_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (reporter_id => users.id)
#
class Project::Report < ApplicationRecord
    belongs_to :reporter, class_name: "User"
    belongs_to :project
    after_create :notify_slack_channel

    REASONS = %w[low_effort undeclared_ai demo_broken other].freeze

    enum :status, { pending: 0, reviewed: 1, dismissed: 2 }, default: :pending

    validates :reason, presence: true, inclusion: { in: REASONS }
    validates :details, presence: true, length: { minimum: 20 }
    validates :reporter_id, uniqueness: { scope: :project_id, message: "has already reported this project" }

    validates :reporter, exclusion: {
        in: ->(report) { report.project&.users || [] },
        message: "cannot report own project"
      }, unless: -> { Rails.env.development? }

    private

    def notify_slack_channel
      SendSlackDmJob.perform_later("C0A1YJ9PDAS", "New report received", blocks_path: "notifications/reports/slack_message", locals: { report: self })
    end
end
