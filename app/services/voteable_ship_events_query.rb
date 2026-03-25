class VoteableShipEventsQuery
  def self.call(user:, user_agent: nil)
    new(user:).call
  end

  def initialize(user:)
    @user = user
  end

  def call
    Post::ShipEvent
      .joins(:project, :project_members)
      .where(certification_status: "approved")
      .where(projects: { shadow_banned: false })
      .where(project_members: { shadow_banned: false })
      .where.not(id: @user.votes.select(:ship_event_id))
      .where.not(projects: { id: @user.projects.select(:id) })
  end
end
