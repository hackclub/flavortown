namespace :ship_events do
  desc "Backfill ship_event_id on votes and reset counter caches"
  task backfill_votes: :environment do
    Post::ShipEvent.find_each do |ship_event|
      post = Post.find_by(postable: ship_event)
      next unless post

      project = post.project
      ship_event_created_at = post.created_at

      next_ship_post = project.posts
                              .where(postable_type: "Post::ShipEvent")
                              .where("created_at > ?", ship_event_created_at)
                              .order(created_at: :asc)
                              .first

      votes_query = project.votes.where("created_at >= ?", ship_event_created_at)
      votes_query = votes_query.where("created_at < ?", next_ship_post.created_at) if next_ship_post

      votes_query.update_all(ship_event_id: ship_event.id)
      Post::ShipEvent.reset_counters(ship_event.id, :votes)

      puts "ShipEvent ##{ship_event.id}: #{ship_event.reload.votes_count} votes"
    end

    puts "Done!"
  end
end
