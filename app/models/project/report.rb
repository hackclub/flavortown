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
    has_many :review_tokens, class_name: "Report::ReviewToken", foreign_key: :report_id, dependent: :destroy
    after_commit :notify_slack_channel, on: :create

    REASONS = [
      "low_effort",
      "undeclared_ai",
      "demo_broken",
      "fraud",
      "other",
      "External flag",
      "YSWS project flag",
      "Shipwrights project flag"
    ].freeze
    USER_REASONS = %w[low_effort undeclared_ai demo_broken other].freeze # fraud is internal

    enum :status, { pending: 0, reviewed: 1, dismissed: 2 }, default: :pending

    validates :reason, presence: true, inclusion: { in: REASONS }
    validates :details, presence: true, length: { minimum: 20 }
    validates :reporter_id, uniqueness: { scope: :project_id, message: "has already reported this project" }

    validates :reporter, exclusion: {
        in: ->(report) { report.project&.users || [] },
        message: "cannot report own project"
      }, unless: -> { Rails.env.development? || reason == "fraud" }

    private

    def notify_slack_channel
      SendSlackDmJob.perform_later("C0A1YJ9PDAS", "New report received", blocks_path: "notifications/reports/slack_message", locals: { report: self })
      if reason == "demo_broken"
        # Create one-time tokens for quick actions
        review_token = review_tokens.create!(action: "review")
        dismiss_token = review_tokens.create!(action: "dismiss")

        SendSlackDmJob.perform_later("C0ADFNQ2MEF", "Demo broken report needs review", blocks_path: "notifications/reports/demo_broken_slack_message", locals: { report: self, review_token_string: review_token.token, dismiss_token_string: dismiss_token.token })
      end
    end
end
