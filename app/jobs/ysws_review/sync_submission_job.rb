module YswsReview
  class SyncSubmissionJob < ApplicationJob
    queue_as :default

    def perform(submission_id)
      submission = YswsReview::Submission.find_by(id: submission_id)
      return unless submission

      project = submission.project
      reviewer = submission.reviewer

      Rails.logger.info "[YswsReview::SyncSubmissionJob] Syncing submission #{submission_id} to Airtable"
      Rails.logger.info "  Project: #{project.title} (ID: #{project.id})"
      Rails.logger.info "  Reviewer: #{reviewer&.display_name || reviewer&.email || 'Unknown'}"
      Rails.logger.info "  Status: #{submission.status}"
      Rails.logger.info "  Total approved seconds: #{submission.total_approved_seconds}"
      Rails.logger.info "  Total original seconds: #{submission.total_original_seconds}"

      # TODO: Implement actual Airtable API sync
      # Example structure for hours justification:
      # hours_justification = submission.devlog_approvals.map do |approval|
      #   "Devlog #{approval.post_devlog_id}: #{approval.approved_minutes} min (#{approval.approved ? 'approved' : 'rejected'})"
      # end.join("\n")
    end
  end
end
