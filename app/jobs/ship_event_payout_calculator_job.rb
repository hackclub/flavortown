class ShipEventPayoutCalculatorJob < ApplicationJob
  queue_as :default

  def perform
    Post::ShipEvent
      .joins(post: :project)
      .where(certification_status: "approved", payout: nil)
      .find_each do |ship_event|
        # Only process if ship event has enough legitimate votes or project is shadow banned
        legitimate_votes_count = ship_event.votes.legitimate.count
        next unless legitimate_votes_count >= Post::ShipEvent::VOTES_REQUIRED_FOR_PAYOUT || ship_event.project.shadow_banned?

        ShipEventPayoutCalculator.apply!(ship_event)
      end
  end
end
