class OneTime::BackfillEnrichedRefsJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    result = PyramidReferralService.sync_enriched_refs!

    if result[:success]
      Rails.logger.info "[Sales Agent From The Pyramid] Backfill complete. Updated #{result[:updated_count]} users (checked #{result[:checked_count]} users against #{result[:valid_codes_count]} valid codes)."
    else
      Rails.logger.error "[Sales Agent From The Pyramid] Backfill failed: #{result[:error]}"
    end
  end
end
