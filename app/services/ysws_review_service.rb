require "faraday"

module YswsReviewService
  class Error < StandardError; end

  module_function

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
    response = connection.get("/api/admin/ysws_reviews", {
      hours: hours,
      status: status
    })
    response.body
  end

  def fetch_review(review_id)
    response = connection.get("/api/admin/ysws_reviews/#{review_id}")
    Rails.logger.info "[YswsReviewService] fetch_review(#{review_id}): #{response.body.inspect}"
    response.body
  end

  def last_synced_at
    Rails.cache.read(LAST_SYNC_CACHE_KEY)
  end

  def update_last_synced_at!(time = Time.current)
    Rails.cache.write(LAST_SYNC_CACHE_KEY, time)
  end

  def hours_since_last_sync
    last = last_synced_at
    return 24000 if last.nil? # placeholder for 1000 days ago to ensure a full sync on first run
    ((Time.current - last) / 1.hour).ceil
  end
end
