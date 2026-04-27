class VoteMatchmaker
  EARLIEST_WEIGHT = 60
  NEAR_PAYOUT_WEIGHT = 40

  def initialize(user, user_agent: nil)
    @user = user
    @user_agent = user_agent
  end

  def next_ship_event
    result = if rand(100) < EARLIEST_WEIGHT
      find_earliest_ship_event || find_near_payout_ship_event
    else
      find_near_payout_ship_event || find_earliest_ship_event
    end

    result || find_held_unpaid_fallback_ship_event || find_paid_fallback_ship_event
  end

  private

  def find_earliest_ship_event
    voteable_ship_events.order(:created_at, "RANDOM()").find { |ship_event| ship_event.hours.to_f.positive? }
  end

  def find_near_payout_ship_event
    voteable_ship_events.order(votes_count: :desc, created_at: :asc).find { |ship_event| ship_event.hours.to_f.positive? }
  end

  def voteable_ship_events
    VoteableShipEventsQuery.call(user: @user, user_agent: @user_agent, include_held: false, include_paid: false)
  end

  def find_held_unpaid_fallback_ship_event
    held_unpaid_ship_events.order(:created_at, "RANDOM()").find { |ship_event| ship_event.hours.to_f.positive? }
  end

  def held_unpaid_ship_events
    VoteableShipEventsQuery
      .call(user: @user, user_agent: @user_agent, include_held: true, include_paid: false)
      .where(id: VoteDeficitHold.ship_event_ids)
  end

  def find_paid_fallback_ship_event
    VoteableShipEventsQuery
      .call(user: @user, user_agent: @user_agent, include_held: false, include_paid: true)
      .where.not(payout: nil)
      .order(created_at: :desc)
      .limit(50)
      .sample
  end
end
