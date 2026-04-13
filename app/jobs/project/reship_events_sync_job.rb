class Project::ReshipEventsSyncJob < ApplicationJob
  queue_as :default
  CACHE_KEY = "reship_events_sync_timestamps"

  def perform
    # SQL: SELECT project_id, MAX(created_at) AS latest_ship_event_at FROM posts WHERE postable_type = 'Post::ShipEvent' GROUP BY project_id HAVING COUNT(*) > 1
    results = Post
      .where(postable_type: "Post::ShipEvent")
      .group(:project_id)
      .having("COUNT(*) > 1")
      .pluck("project_id, MAX(created_at) AS latest_ship_event_at")

    Rails.logger.info "Found #{results.count} projects with multiple ship events"

    cached_timestamps = Rails.cache.read(CACHE_KEY) || {}
    projects_to_process = results.select do |project_id, latest_ship_event_at|
      cached_timestamp = cached_timestamps[project_id.to_s]
      cached_timestamp.nil? || latest_ship_event_at > cached_timestamp
    end

    Rails.logger.info "Processing #{projects_to_process.count} projects with new/updated ship events"

    projects_to_process.each do |project_id, latest_ship_event_at|
      project = Project.find(project_id)
      begin
        ShipCertService.ship_to_dash(project, type: "resend")
        Rails.logger.info "Successfully resent project #{project.id} to ship cert platform"
        cached_timestamps[project_id.to_s] = latest_ship_event_at
      rescue => e
        Rails.logger.error "Failed to resend project #{project.id} to ship cert platform: #{e.message}"
      end
    end

    Rails.cache.write(CACHE_KEY, cached_timestamps)
    Rails.logger.info "Updated cache with #{cached_timestamps.count} project timestamps"
  end
end
