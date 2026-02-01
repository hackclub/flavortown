class AddSuspiciousToVotes < ActiveRecord::Migration[8.1]
  def up
    add_column :votes, :suspicious, :boolean, default: false, null: false
    add_index :votes, [ :suspicious, :created_at ]

    # Backfill suspicious votes from last 7 days
    # Use update_all for performance (bulk update)
    # Note: This bypasses PaperTrail audit logging and model callbacks
    # which is acceptable for this one-time backfill operation
    puts "Marking suspicious votes from last 7 days..."
    Vote.where(
      "created_at >= ? AND time_taken_to_vote < ?",
      7.days.ago.beginning_of_day,
      30  # literal threshold value (Vote::SUSPICIOUS_VOTE_THRESHOLD)
    ).update_all(suspicious: true)

    suspicious_count = Vote.where(suspicious: true).count
    puts "Marked #{suspicious_count} votes as suspicious"

    # Note: Payout recalculation is intentionally skipped
    # Suspicious votes will be excluded from future calculations automatically
    # Payouts will adjust naturally as new legitimate votes come in
  end

  def down
    remove_index :votes, [ :suspicious, :created_at ]
    remove_column :votes, :suspicious
  end
end
