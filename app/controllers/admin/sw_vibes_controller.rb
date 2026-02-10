module Admin
  class SwVibesController < Admin::ApplicationController
    def index
      authorize :admin, :access_sw_vibes?

      @data = fetch_sw_vibes_data
      @error = @data[:error] if @data.is_a?(Hash) && @data[:error]
    end

    private

    def fetch_sw_vibes_data
      Rails.cache.fetch("sw_vibes_data", expires_in: 5.minutes) do
        fetch_from_api
      end
    rescue StandardError => e
      Rails.logger.error "SW Vibes API Error: #{e.message}"
      { error: e.message }
    end

    def fetch_from_api
      response = Faraday.get("https://ai.review.hackclub.com/metrics/qualitative") do |req|
        req.headers["X-API-Key"] = ENV["SWAI_KEY"]
        req.options.timeout = 10
        req.options.open_timeout = 5
      end

      unless response.success?
        Rails.logger.error "SW Vibes API returned #{response.status}: #{response.body}"
        return { error: "API died (#{response.status})" }
      end

      JSON.parse(response.body, symbolize_names: true)
    rescue Faraday::Error => e
      Rails.logger.error "SW Vibes Faraday Error: #{e.message}"
      { error: "Couldn't reach the API" }
    rescue JSON::ParserError => e
      Rails.logger.error "SW Vibes JSON Parse Error: #{e.message}"
      { error: "Got a weird response" }
    end
  end
end
