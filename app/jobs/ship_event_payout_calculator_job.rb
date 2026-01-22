class ShipEventPayoutCalculatorJob < ApplicationJob
  queue_as :default

  def perform
    Post::ShipEvent
      .where(certification_status: "approved", payout: nil)
      .where("votes_count >= ?", Post::ShipEvent::VOTES_REQUIRED_FOR_PAYOUT)
      .find_each do |ship_event|
        ShipEventPayoutCalculator.apply!(ship_event)
      end
  end
end
