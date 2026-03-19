class OneTime::FixNullShipEvents < ApplicationJob
  queue_as :literally_whenever

  NOTIFY_USER_ID = "U07L45W79E1"

  def perform(dry_run: true)
    Post::ShipEvent.where(hours: nil).find_each do |ship_event|
      project = ship_event.project

      if project.nil?
        Rails.logger.info "[FixNullShipEvents] #{"(DRY RUN) " if dry_run}ShipEvent ##{ship_event.id} has no project, would delete"
        ship_event.destroy unless dry_run
        next
      end

      calculated_hours = ship_event.hours

      if calculated_hours > 0
        Rails.logger.info "[FixNullShipEvents] #{"(DRY RUN) " if dry_run}ShipEvent ##{ship_event.id} -> #{calculated_hours} hours"
        unless dry_run
          ship_event.update_column(:hours, calculated_hours)

          if ship_event.certification_status == "approved" && ship_event.overall_percentile.present? && ship_event.payout.blank?
            ShipEventPayoutCalculator.apply!(ship_event)
            Rails.logger.info "[FixNullShipEvents] ShipEvent ##{ship_event.id} payout issued: #{ship_event.reload.payout} cookies"
          end
        end
      else
        project_url = "https://flavortown.hackclub.com/projects/#{project&.id}"
        Rails.logger.warn "[FixNullShipEvents] #{"(DRY RUN) " if dry_run}ShipEvent ##{ship_event.id} has 0 hours: #{project_url}"
        # unless dry_run
        SendSlackDmJob.perform_later(NOTIFY_USER_ID, "🚨 ShipEvent ##{ship_event.id} has 0 hours and couldn't be fixed: #{project_url}")
        # end
      end
    end
  end
end
