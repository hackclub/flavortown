class AddSuspiciousToVotes < ActiveRecord::Migration[8.1]
  def up
    add_column :votes, :suspicious, :boolean, default: false, null: false
    add_index :votes, [ :suspicious, :created_at ]

    # Backfill suspicious votes from last 7 days
    puts "Marking suspicious votes from last 7 days..."
    Vote.where(
      "created_at >= ? AND time_taken_to_vote < ?",
      7.days.ago.beginning_of_day,
      Vote::SUSPICIOUS_VOTE_THRESHOLD
    ).update_all(suspicious: true)

    suspicious_count = Vote.where(suspicious: true).count
    puts "Marked #{suspicious_count} votes as suspicious"

    # Recalculate payouts for affected ship events
    puts "Recalculating payouts for affected ship events..."
    affected_ship_event_ids = Vote.suspicious_votes
                                   .where("created_at >= ?", 7.days.ago.beginning_of_day)
                                   .distinct
                                   .pluck(:ship_event_id)

    affected_ship_event_ids.each do |ship_event_id|
      ship_event = Post::ShipEvent.find_by(id: ship_event_id)
      next unless ship_event

      # Update metrics using legitimate votes only
      metrics = MajorityJudgmentService.call(ship_event)
      ship_event.update_columns(
        originality_median: metrics[:medians][:originality],
        technical_median: metrics[:medians][:technical],
        usability_median: metrics[:medians][:usability],
        storytelling_median: metrics[:medians][:storytelling],
        overall_score: metrics[:overall_score],
        originality_percentile: metrics[:percentiles][:originality],
        technical_percentile: metrics[:percentiles][:technical],
        usability_percentile: metrics[:percentiles][:usability],
        storytelling_percentile: metrics[:percentiles][:storytelling],
        overall_percentile: metrics[:overall_percentile],
        updated_at: Time.current
      )

      # Recalculate payout if eligible
      if ship_event.votes_count.to_i >= Post::ShipEvent::VOTES_REQUIRED_FOR_PAYOUT
        ShipEventPayoutCalculator.apply!(ship_event)
      end
    end

    puts "Recalculated #{affected_ship_event_ids.count} ship events"
  end

  def down
    remove_index :votes, [ :suspicious, :created_at ]
    remove_column :votes, :suspicious
  end
end
