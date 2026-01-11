class PyramidReferralService
  BASE_URL = "https://pyramid.hackclub.com"

  class << self
    # Fetch the list of valid referral codes from Pyramid API
    def fetch_valid_referral_codes
      response = connection.get("api/v1/referrals_valid")

      if response.success?
        data = JSON.parse(response.body)
        data["referral_codes"] || []
      else
        Rails.logger.error "PyramidReferralService error: #{response.status} - #{response.body}"
        nil
      end
    rescue => e
      Rails.logger.error "PyramidReferralService exception: #{e.message}"
      nil
    end

    # Sync enriched_ref by cross-checking user ref values against valid Pyramid codes
    def sync_enriched_refs!
      valid_codes = fetch_valid_referral_codes
      return { success: false, error: "Failed to fetch valid referral codes" } unless valid_codes

      valid_codes_set = valid_codes.to_set

      # Find all users with a ref that exists in the valid codes list
      users_with_refs = User.where.not(ref: [ nil, "" ])
      updated_count = 0
      checked_count = 0

      users_with_refs.find_each do |user|
        checked_count += 1
        # If the user's ref exists in valid Pyramid codes, copy to enriched_ref
        if valid_codes_set.include?(user.ref) && user.enriched_ref != user.ref
          user.update!(enriched_ref: user.ref)
          updated_count += 1
        end
      end

      { success: true, updated_count: updated_count, checked_count: checked_count, valid_codes_count: valid_codes.size }
    rescue => e
      Rails.logger.error "PyramidReferralService.sync_enriched_refs! error: #{e.message}"
      { success: false, error: e.message }
    end

    private

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |conn|
        conn.headers["Content-Type"] = "application/json"
        conn.headers["Authorization"] = ENV["PYRAMID_CAMPAIGN_KEY"]
        conn.headers["User-Agent"] = Rails.application.config.user_agent
      end
    end
  end
end
