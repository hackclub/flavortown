class VoteableShipEventsQuery
  EXCLUDED_CATEGORIES_BY_OS = {
    windows: [ "Desktop App (Linux)", "Desktop App (macOS)" ],
    mac: [ "Desktop App (Windows)" ],
    linux: [ "Desktop App (Windows)" ],
    android: [ "Desktop App (Windows)", "Desktop App (Linux)", "Desktop App (macOS)", "iOS App" ],
    ios: [ "Desktop App (Windows)", "Desktop App (Linux)", "Desktop App (macOS)", "Android App" ]
  }.freeze

  def self.call(user:, user_agent: nil, include_held: true, include_paid: true)
    new(user:, user_agent:, include_held:, include_paid:).call
  end

  def initialize(user:, user_agent: nil, include_held: true, include_paid: true)
    @user = user
    @user_agent = user_agent
    @include_held = include_held
    @include_paid = include_paid
  end

  def call
    scope = unpaid_ship_events
    scope = scope.where.not(id: VoteDeficitHold.ship_event_ids) unless @include_held

    return scope unless include_paid?

    scope.or(paid_ship_events)
  end

  private

  def include_paid?
    @include_paid && @user.vote_balance.negative?
  end

  def base_ship_events
    scope = Post::ShipEvent
      .current_voting_scale
      .joins(:project, :project_members)
      .where(certification_status: "approved")
      .where(projects: { shadow_banned: false })
      .where.not(id: @user.votes.select(:ship_event_id))
      .where.not(projects: { id: @user.projects.select(:id) })
      .where.not(projects: { id: @user.reports.select(:project_id) })
      .where.not(projects: { id: @user.project_skips.select(:project_id) })

    excluded_categories.each do |category|
      scope = scope.where.not("? = ANY(projects.project_categories)", category)
    end

    scope
  end

  def unpaid_ship_events
    base_ship_events
      .where(payout: nil)
      .where.not(id: full_ship_event_ids)
  end

  def paid_ship_events
    base_ship_events.where.not(payout: nil)
  end

  def full_ship_event_ids
    Vote
      .payout_countable
      .group(:ship_event_id)
      .having("COUNT(*) >= ?", Post::ShipEvent::VOTES_TO_LEAVE_POOL)
      .select(:ship_event_id)
  end

  def excluded_categories
    EXCLUDED_CATEGORIES_BY_OS[detect_os] || []
  end

  def detect_os
    return nil unless @user_agent

    user_agent = @user_agent.downcase
    return :android if user_agent.include?("android")
    return :ios if user_agent.include?("iphone") || user_agent.include?("ipod") || user_agent.include?("ipad")
    return :ios if user_agent.include?("macintosh") && (user_agent.include?("mobile") || user_agent.include?("cpu os") || user_agent.include?("ipad"))
    return :windows if user_agent.include?("windows")
    return :mac if user_agent.include?("macintosh")
    return :linux if user_agent.include?("linux")

    nil
  end
end
