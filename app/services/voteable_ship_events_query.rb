class VoteableShipEventsQuery
  EXCLUDED_CATEGORIES_BY_OS = VoteMatchmaker::EXCLUDED_CATEGORIES_BY_OS

  def self.call(user:, user_agent: nil)
    new(user:, user_agent:).call
  end

  def initialize(user:, user_agent: nil)
    @user = user
    @user_agent = user_agent.to_s
    @os = detect_os(@user_agent)
  end

  def call
    scope = Post::ShipEvent
      .current_voting_scale
      .joins(post: :project)
      .joins(project_memberships: :user)
      .where(certification_status: "approved")
      .where(projects: { deleted_at: nil, shadow_banned: false })
      .where(project_memberships: { role: "owner" })
      .where(users: { shadow_banned: false })
      .where("projects.duration_seconds > 0")
      .where.not(id: @user.votes.select(:ship_event_id))
      .where.not(projects: { id: @user.projects.select(:id) })
      .where.not(id: full_ship_event_ids)

    excluded_categories.each do |category|
      scope = scope.where.not("? = ANY(projects.project_categories)", category)
    end

    scope
  end

  private

  def detect_os(ua)
    return nil if ua.blank?
    return :android if ua.include?("Android")
    return :ios if ua.include?("iPhone") || ua.include?("iPad")
    return :windows if ua.include?("Windows")
    return :mac if ua.include?("Macintosh")
    return :linux if ua.include?("Linux")
    nil
  end

  def excluded_categories
    EXCLUDED_CATEGORIES_BY_OS[@os] || []
  end

  def full_ship_event_ids
    Vote
      .legitimate
      .group(:ship_event_id)
      .having("COUNT(*) >= ?", Post::ShipEvent::VOTES_TO_LEAVE_POOL)
      .select(:ship_event_id)
  end
end
