require "faraday"

module YswsReviewService
  class Error < StandardError; end

  module_function

  DISABLED = false # Set to false to re-enable the service

  BASE_URL = "https://review.hackclub.com"
  LAST_SYNC_CACHE_KEY = "ysws_review_sync:last_fetched_at"

  def api_key
    Rails.application.credentials.dig(:ysws_review, :api_key) || ENV["YSWS_REVIEW_API_KEY"]
  end

  def connection
    Faraday.new(url: BASE_URL) do |conn|
      conn.request :json
      conn.response :json
      conn.response :raise_error
      conn.headers["x-api-key"] = api_key
      conn.headers["Accept"] = "application/json"
    end
  end

  def fetch_reviews(hours:, status: "done")
    return [] if DISABLED

    response = connection.get("/api/admin/ysws_reviews", {
      hours: hours,
      status: status
    })
    response.body
  end

  def fetch_review(review_id)
    return nil if DISABLED

    response = connection.get("/api/admin/ysws_reviews/#{review_id}")
    Rails.logger.info "[YswsReviewService] fetch_review(#{review_id}) response status: #{response.status}"
    response.body
  end

  def last_synced_at
    Rails.cache.read(LAST_SYNC_CACHE_KEY)
  end

  def update_last_synced_at!(time = Time.current)
    return if DISABLED

    Rails.cache.write(LAST_SYNC_CACHE_KEY, time)
  end

  def hours_since_last_sync
    240000
  end
end
