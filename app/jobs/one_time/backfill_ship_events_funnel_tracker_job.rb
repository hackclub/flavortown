class OneTime::BackfillShipEventsFunnelTrackerJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    # find first ship event for a given user id
    first_ship_post_ids = Post.of_ship_events
                              .group(:user_id)
                              .minimum(:id)
                              .values

    Post.where(id: first_ship_post_ids)
        .includes(:user, :postable, :project)
        .find_each do |post|
      ship_event = post.postable

      FunnelTrackerService.track(
        event_name: "ship_event_created",
        user: post.user,
        properties: { ship_event_id: ship_event.id, project_id: post.project.id }
      )
    end
  end
end
