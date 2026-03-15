module Lapse
  # Background job to warm the Lapse timelapses cache for a project.
  # Enqueued when a project page is viewed and the cache is empty.
  class CacheProjectTimelapsesJob < ApplicationJob
    queue_as :literally_whenever

    # @param project_id [Integer]
    def perform(project_id)
      project = Project.find_by(id: project_id)
      return unless project

      timelapses = TimelapsesFetcher.new(project: project).call
      TimelapsesCache.write(project, timelapses)
    end
  end
end
