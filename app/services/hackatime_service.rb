class HackatimeService
  BASE_URL = "https://hackatime.hackclub.com"
  START_DATE = "2025-11-05"

  def self.fetch_authenticated_user(access_token)
    response = connection.get("authenticated/me") do |req|
      req.headers["Authorization"] = "Bearer #{access_token}"
    end

    if response.success?
      data = JSON.parse(response.body)
      data["id"]&.to_s
    else
      Rails.logger.error "HackatimeService authenticated/me error: #{response.status}"
      nil
    end
  rescue => e
    Rails.logger.error "HackatimeService authenticated/me exception: #{e.message}"
    nil
  end

  def self.fetch_stats(hackatime_uid, start_date: START_DATE, end_date: nil)
    params = { features: "projects", start_date: start_date }
    params[:end_date] = end_date if end_date

    response = connection.get("users/#{hackatime_uid}/stats", params)

    if response.success?
      data = JSON.parse(response.body)
      projects = data.dig("data", "projects") || []
      {
        projects: projects.reject { |p| User::HackatimeProject::EXCLUDED_NAMES.include?(p["name"]) }
                          .to_h { |p| [ p["name"], p["total_seconds"].to_i ] },
        banned: data.dig("trust_factor", "trust_value") == 1
      }
    else
      Rails.logger.error "HackatimeService error: #{response.status} - #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "HackatimeService exception: #{e.message}"
    nil
  end

  class << self
    private

    def connection
      @connection ||= Faraday.new(url: "#{BASE_URL}/api/v1") do |conn|
        conn.headers["Content-Type"] = "application/json"
        conn.headers["User-Agent"] = Rails.application.config.user_agent
        conn.headers["RACK_ATTACK_BYPASS"] = ENV["HACKATIME_BYPASS_KEYS"] if ENV["HACKATIME_BYPASS_KEYS"].present?
      end
    end
  end
end
