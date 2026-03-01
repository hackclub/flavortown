class Cache::ProjectLapseTimelapsesJob < ApplicationJob
  queue_as :literally_whenever

  CACHE_TTL = 10.minutes

  def self.cache_key(project_id)
    "projects:lapse_timelapses:#{project_id}"
  end

  def perform(project_id)
    project = Project.find_by(id: project_id)
    return unless project

    timelapses = ProjectLapseTimelapsesFetcher.new(project).call
    Rails.cache.write(self.class.cache_key(project.id), timelapses, expires_in: CACHE_TTL)
  end
end
