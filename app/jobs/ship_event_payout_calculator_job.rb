class ShipEventPayoutCalculatorJob < ApplicationJob
  queue_as :default

  def perform
    Post::ShipEvent
      .joins(post: :project)
      .where(certification_status: "approved", payout: nil)
      .where("votes_count >= ? OR projects.shadow_banned = ?", Post::ShipEvent::VOTES_REQUIRED_FOR_PAYOUT, true)
      .find_each do |ship_event|
        ShipEventPayoutCalculator.apply!(ship_event)
      end
  end
end
