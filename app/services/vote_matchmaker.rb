class VoteMatchmaker
  EXCLUDED_CATEGORIES_BY_OS = {
    windows: [ "Desktop App (Linux)", "Desktop App (macOS)" ],
    mac: [ "Desktop App (Windows)" ],
    linux: [ "Desktop App (Windows)" ]
  }.freeze

  def initialize(user, user_agent: nil)
    @user = user
    @os = detect_os(user_agent)
  end

  def next_ship_event
    find_ship_event_for_category(next_category) || find_any_ship_event
  end

  private

  def detect_os(ua)
    return nil unless ua
    return :windows if ua.include?("Windows")
    return :mac if ua.include?("Macintosh")
    return :linux if ua.include?("Linux") && !ua.include?("Android")
    nil
  end

  def available_categories
    Project::AVAILABLE_CATEGORIES - (EXCLUDED_CATEGORIES_BY_OS[@os] || [])
  end

  def next_category
    # very dumb way to ensure categories are cycled and people don't vote on the same category all the time
    # the caveat: only works if the user votes.
    available_categories[@user.votes.count % available_categories.size]
  end

  def find_ship_event_for_category(category)
    voteable_ship_events
      .where("? = ANY(projects.project_categories)", category)
      .order(:votes_count, "RANDOM()")
      .first
  end

  def find_any_ship_event
    voteable_ship_events.order(:votes_count, "RANDOM()").first
  end

  def voteable_ship_events
    Post::ShipEvent
      .joins(:project, :project_members)
      .where(certification_status: "approved")
      .where(payout: nil)
      .where.not(id: @user.votes.select(:ship_event_id))
      .where.not(projects: { id: @user.projects })
      .where(project_members: { shadow_banned: false })
  end
end
