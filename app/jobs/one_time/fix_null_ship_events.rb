class OneTime::FixNullShipEvents < ApplicationJob
  queue_as :literally_whenever

  NOTIFY_USER_ID = "U05F4B48GBF"

  def perform(dry_run: true)
    deleted = 0
    migrated = 0

    Post::ShipEvent.where(hours: nil).find_each do |ship_event|
      project = ship_event.project
      calculated_hours = project ? ship_event.hours : nil
      log_prefix = "[FixNullShipEvents]#{" (DRY RUN)" if dry_run} ShipEvent ##{ship_event.id}"

      if project.nil? || calculated_hours <= 0
        reason = project.nil? ? "no project" : "0 hours (#{project_url(project)})"
        Rails.logger.warn "#{log_prefix} deleting: #{reason}"
        next if dry_run

        ship_event_id = ship_event.id
        notify_members_deleted(project) if project
        Vote.where(ship_event_id: ship_event_id).delete_all
        ship_event.reload.destroy
        notify_admin("ShipEvent ##{ship_event_id} deleted: #{reason}.")
        deleted += 1
        next
      end

      next if dry_run

      if ship_event.legacy_voting_scale? && ship_event.certification_status == "approved" && ship_event.payout.blank?
        vote_count = ship_event.votes.count
        clear_legacy_votes!(ship_event)
        notify_members_migrated(project, calculated_hours)
        migrated += 1
        Rails.logger.info "#{log_prefix} migrated to current voting scale (#{vote_count} votes cleared)"
      end
    end

    Rails.logger.info "[FixNullShipEvents]#{" (DRY RUN)" if dry_run} done — #{deleted} deleted, #{migrated} migrated to current scale"
    ShipEventMajorityJudgmentRefreshJob.perform_later if migrated > 0
  end

  private

  def project_url(project)
    "https://flavortown.hackclub.com/projects/#{project.id}"
  end

  def notify_admin(message)
    SendSlackDmJob.perform_later(NOTIFY_USER_ID, message)
  end

  def notify_members_deleted(project)
    message = "Hey! A ship event for your project \"#{project.title}\" was removed because it had 0 hours logged. " \
              "Please re-ship with the correct hours attached. If you believe this was a mistake, reach out to @Fraud Squad."
    send_to_members(project, message)
  end

  def notify_members_migrated(project, hours)
    message = "Hey! A ship event for your project \"#{project.title}\" (#{hours.round(1)}h) has been processed and paid out. " \
              "No action needed on your end!"
    send_to_members(project, message)
  end

  def send_to_members(project, message)
    project.users.each do |user|
      next unless user.slack_id.present?
      SendSlackDmJob.perform_later(user.slack_id, message)
    end
  end

  # wipes legacy-scale votes if any and bumps to current scale so voting can run normally.
  def clear_legacy_votes!(ship_event)
    ActiveRecord::Base.transaction do
      user_ids = ship_event.votes.distinct.pluck(:user_id)
      ship_event.votes.delete_all
      Post::ShipEvent.reset_counters(ship_event.id, :votes)
      user_ids.each { |uid| User.reset_counters(uid, :votes) }
      ship_event.update_column(:voting_scale_version, Post::ShipEvent::CURRENT_VOTING_SCALE_VERSION)
    end
  end
end
