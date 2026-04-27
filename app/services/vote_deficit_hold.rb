class VoteDeficitHold
  MIN_COUNTABLE_VOTES = 1

  class << self
    def ship_events
      unpaid_negative_balance_ship_events
        .where(id: countable_ship_event_ids(MIN_COUNTABLE_VOTES))
        .distinct
    end

    def ship_event_ids
      ship_events.select("post_ship_events.id")
    end

    def unpaid_negative_balance_ship_events
      Post::ShipEvent
        .current_voting_scale
        .joins(post: :user)
        .where(certification_status: "approved", payout: nil)
        .where("users.vote_balance < 0")
    end

    def notification_recipients
      User
        .where(id: unpaid_negative_balance_ship_events.select("users.id"))
        .where.not(slack_id: nil)
        .where.not(slack_id: "")
        .distinct
    end

    def held_notification_recipients
      User
        .where(id: ship_events.select("users.id"))
        .where.not(slack_id: nil)
        .where.not(slack_id: "")
        .distinct
    end

    private

    def countable_ship_event_ids(min_votes)
      Vote
        .payout_countable
        .group(:ship_event_id)
        .having("COUNT(*) >= ?", min_votes)
        .select(:ship_event_id)
    end
  end
end
