class ProjectLapseTimelapsesFetcher
  def initialize(project)
    @project = project
  end

  def call
    return [] unless ENV["LAPSE_API_BASE"].present?
    return [] unless @project.hackatime_keys.present?

    hackatime_identity = @project.users.first&.hackatime_identity
    return [] unless hackatime_identity&.uid.present?

    timelapses = LapseService.fetch_all_timelapses_for_projects(
      hackatime_user_id: hackatime_identity.uid,
      project_keys: @project.hackatime_keys
    ) || []
    timelapses.sort_by { |t| -(t["createdAt"] || 0) }
  rescue StandardError
    []
  end
end
