class VoteMatchmaker
  EXCLUDED_CATEGORIES_BY_OS = {
    windows: [ "Desktop App (Linux)", "Desktop App (macOS)" ],
    mac: [ "Desktop App (Windows)" ],
    linux: [ "Desktop App (Windows)" ],
    android: [ "Desktop App (Windows)", "Desktop App (Linux)", "Desktop App (macOS)", "iOS App" ],
    ios: [ "Desktop App (Windows)", "Desktop App (Linux)", "Desktop App (macOS)", "Android App" ]
  }.freeze

  EARLIEST_WEIGHT = 60
  NEAR_PAYOUT_WEIGHT = 40

  def initialize(user, user_agent: nil)
    @user = user
    @os = detect_os(user_agent)
  end

  def next_ship_event
    if rand(100) < EARLIEST_WEIGHT
      find_earliest_ship_event || find_near_payout_ship_event
    else
      find_near_payout_ship_event || find_earliest_ship_event
    end
  end

  private

  def detect_os(ua)
    return nil unless ua
    s = ua.downcase

    return :android if s.include?("android")
    return :ios if s.include?("iphone") || s.include?("ipod") || s.include?("ipad")
    if s.include?("macintosh") && (s.include?("mobile") || s.include?("cpu os") || s.include?("ipad"))
      return :ios
    end

    return :windows if s.include?("windows")
    return :mac if s.include?("macintosh")
    return :linux if s.include?("linux")
    nil
  end

  def excluded_categories
    EXCLUDED_CATEGORIES_BY_OS[@os] || []
  end

  def find_earliest_ship_event
    voteable_ship_events.order(:created_at, "RANDOM()").first
  end

  def find_near_payout_ship_event
    voteable_ship_events.order(votes_count: :desc, created_at: :asc).first
  end

  def voteable_ship_events
    scope = Post::ShipEvent
      .joins(:project, :project_members)
      .where(certification_status: "approved")
      .where(payout: nil)
      .where.not(id: @user.votes.select(:ship_event_id))
      .where.not(projects: { id: @user.projects })
      .where.not(projects: { id: @user.reports.select(:project_id) })
      .where(project_members: { shadow_banned: false })
      .where(projects: { shadow_banned: false })
      .where("projects.duration_seconds > 0")
      .where.not(id: vote_deficit_blocked_ship_event_ids)

    excluded_categories.each do |category|
      scope = scope.where.not("? = ANY(projects.project_categories)", category)
    end

    scope
  end

  def vote_deficit_blocked_ship_event_ids
    Post::ShipEvent
      .joins(post: :user)
      .where("post_ship_events.votes_count >= ?", Post::ShipEvent::VOTES_REQUIRED_FOR_PAYOUT)
      .where("users.vote_balance < 0")
      .select("post_ship_events.id")
  end
end
