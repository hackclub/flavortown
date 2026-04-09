class Project::ShipEventsSyncJob < ApplicationJob
  queue_as :default

  def perform
    # Find all project_ids that have multiple Post::ShipEvent records
    # SQL: SELECT project_id FROM posts WHERE postable_type = 'Post::ShipEvent' GROUP BY project_id HAVING COUNT(*) > 1
    project_ids = Post
      .where(postable_type: "Post::ShipEvent")
      .group(:project_id)
      .having("COUNT(*) > 1")
      .pluck(:project_id)

    Rails.logger.info "Found #{project_ids.count} projects with multiple ship events"

    project_ids.each do |project_id|
      project = Project.find(project_id)
      Rails.logger.info "Syncing project #{project.id} (#{project.title})"

      # Log each ship event for this project
      project.ship_events.each do |ship_event|
        console.log "Ship Event ID: #{ship_event.id}, Project: #{project.title}, Created: #{ship_event.created_at}, Body: #{ship_event.body&.truncate(100)}"
      end
    end
  end
end
