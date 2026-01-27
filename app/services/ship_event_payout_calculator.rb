class ShipEventPayoutCalculator
  def self.apply!(ship_event)
    new(ship_event).apply!
  end

  def initialize(ship_event, game_constants: Rails.configuration.game_constants)
    @ship_event = ship_event
    @game_constants = game_constants
  end

  def apply!
    payout_user = @ship_event.payout_recipient
    return unless payout_user

    unless payout_eligible?
      if payout_user.vote_balance < 0
        notify_vote_deficit(payout_user, payout_user.vote_balance.abs)
      end
      return
    end

    @ship_event.with_lock do
      return unless payout_eligible?

      hours_used = base_hours
      puts hours_used
      return if hours_used <= 0

      percentile = @ship_event.overall_percentile
      return if percentile.nil?
      puts percentile

      hourly_rate = dollars_per_hour_for_percentile(percentile)
      return if hourly_rate <= 0
      puts hourly_rate

      dollars = hours_used * hourly_rate
      cookies = (dollars * tickets_per_dollar).round
      return if cookies <= 0
      puts cookies

      # mult is like if mult is 30 then you have $6/hr. or you get 30 cookies so its how many cookies you get
      mult = (hourly_rate * tickets_per_dollar).round(6)

      ActiveRecord::Base.transaction do
        attrs = { payout: cookies, multiplier: mult, hours: hours_used }

        @ship_event.update!(attrs)

        payout_user.ledger_entries.create!(
          ledgerable: @ship_event,
          amount: cookies,
          reason: payout_reason,
          created_by: "ship_event_payout"
        )
      end

      notify_payout_issued(payout_user)
    end
  end

  private

  def payout_eligible?
    @ship_event.payout_eligible?
  end

  def base_hours
    hours = @ship_event.hours
    hours.to_f if hours.present?
  end

  def dollars_per_hour_for_percentile(percentile)
    p = (percentile.to_f / 100.0).clamp(0.0, 1.0)
    low  = lowest_dollar_per_hour   # 0.30
    high = highest_dollar_per_hour  # 6.00
    return 0.0 if high <= 0 || low < 0 || high < low

    gamma = 1.745427173
    rate = low + (high - low) * (p ** gamma)
    rate.clamp(low, high)
  end

  def payout_reason
    project = @ship_event.post&.project
    return "Ship event payout" unless project

    "Ship event payout: #{project.title}"
  end

  def lowest_dollar_per_hour = @game_constants.lowerst_dollar_per_hour.to_f
  def highest_dollar_per_hour = @game_constants.highest_dollar_per_hour.to_f
  def dollars_per_mean_hour = @game_constants.dollars_per_mean_hour.to_f
  def tickets_per_dollar = @game_constants.tickets_per_dollar.to_f

  def notify_payout_issued(user)
    return unless user.slack_id.present?

    SendSlackDmJob.perform_later(
      user.slack_id,
      nil,
      blocks_path: "notifications/payouts/ship_event_issued",
      locals: { ship_event: @ship_event }
    )
  end

  def notify_vote_deficit(user, votes_needed)
    return unless user.slack_id.present?

    project = @ship_event.post&.project
    project_title = project&.title

    SendSlackDmJob.perform_later(
      user.slack_id,
      nil,
      blocks_path: "notifications/payouts/vote_deficit_blocked",
      locals: {
        ship_event: @ship_event,
        votes_needed: votes_needed,
        project_title: project_title
      }
    )
  end
end
