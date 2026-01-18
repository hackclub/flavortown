class SyncPyramidEnrichedRefsJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    result = PyramidReferralService.sync_enriched_refs!

    if result[:success]
      Rails.logger.info "[The Pyramid of Clubiza] We're chilling! Updated #{result[:updated_count]} users (checked #{result[:checked_count]} users against #{result[:valid_codes_count]} valid codes)."
    else
      Rails.logger.error "[The Pyramid of Clubiza] Oops: #{result[:error]}"
    end
  end
end
