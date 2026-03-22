class OneTime::PurgeZeroHourShipEventsJob < ApplicationJob
  queue_as :literally_whenever

  SHIP_EVENT_IDS = [
    24, 43, 49, 128, 224, 235, 346, 408,
    563, 889, 1362, 1366, 1545, 1563, 1637, 1675
  ].freeze

  def perform
    ship_events = Post::ShipEvent.where(id: SHIP_EVENT_IDS).includes(post: { project: { memberships: :user } })

    purged = 0
    skipped = 0

    ship_events.find_each do |ship_event|
      post = ship_event.post
      project = post&.project

      unless project
        Rails.logger.warn "[PurgeZeroHourShipEvents] ShipEvent ##{ship_event.id}: no project found, skipping"
        skipped += 1
        next
      end

      owner = project.memberships.find { |m| m.role == "owner" }&.user

      if owner&.slack_id.present?
        owner.dm_user(
          "Hey! Your ship \"#{project.title}\" had been shipped with no devlog attached to it, " \
          "so it has been removed. If you believe this was a mistake, please reach out to @cskartikey or send a msg in #flavortown-help. " \
          "You can re-ship once you've logged some devlog time!"
        )
        Rails.logger.info "[PurgeZeroHourShipEvents] DMed #{owner.slack_id} for project #{project.id} (#{project.title})"
      else
        Rails.logger.warn "[PurgeZeroHourShipEvents] ShipEvent ##{ship_event.id}: no owner slack_id, skipping DM"
      end

      ship_event.destroy!
      purged += 1

      Rails.logger.info "[PurgeZeroHourShipEvents] Purged ShipEvent ##{ship_event.id} from project #{project.id} (#{project.title})"
    end

    Rails.logger.info "[PurgeZeroHourShipEvents] Complete. purged=#{purged}, skipped=#{skipped}"
  end
end
