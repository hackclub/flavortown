module OneTime
  class MarkSuspiciousVotesJob < ApplicationJob
    queue_as :default

    def perform
      mark_suspicious_votes
      recalculate_affected_payouts
    end

    private

    def mark_suspicious_votes
      # Find votes from last 7 days that took less than 30s and aren't already marked
      suspicious_votes = Vote.where(
        "created_at >= ? AND time_taken_to_vote < ? AND suspicious = false",
        7.days.ago.beginning_of_day,
        Vote::SUSPICIOUS_VOTE_THRESHOLD
      )

      count = suspicious_votes.count

      suspicious_votes.find_each do |vote|
        vote.update_columns(suspicious: true)
      end

      Rails.logger.info("OneTime::MarkSuspiciousVotesJob: Marked #{count} votes as suspicious from the last 7 days")
    end

    def recalculate_affected_payouts
      # Find unique ship events affected by suspicious votes in the last 7 days
      affected_ship_event_ids = Vote.suspicious_votes
                                     .where("created_at >= ?", 7.days.ago.beginning_of_day)
                                     .distinct
                                     .pluck(:ship_event_id)

      return if affected_ship_event_ids.empty?

      Rails.logger.info("OneTime::MarkSuspiciousVotesJob: Recalculating payouts for #{affected_ship_event_ids.count} ship events")

      affected_ship_event_ids.each do |ship_event_id|
        ship_event = Post::ShipEvent.find_by(id: ship_event_id)
        next unless ship_event

        # Recalculate majority judgment scores (which will also trigger payout recalculation)
        MajorityJudgmentService.call(ship_event)

        # Update ship event metrics
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

      Rails.logger.info("OneTime::MarkSuspiciousVotesJob: Completed recalculation for #{affected_ship_event_ids.count} ship events")
    end
  end
end
