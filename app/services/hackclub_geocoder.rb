# frozen_string_literal: true

class HackclubGeocoder
  API_URL = "https://geocoder.hackclub.com/"

  class << self
    def geocode_ip(ip)
      return nil if ip.blank?

      response = conn.get("v1/geoip", {
        ip: ip,
        key: ENV["GEOCODER_HC_API_KEY"]
      })

      if response.body.key?("error")
        Rails.logger.error "Hack Club Geocoder error: #{response.body["error"]}"
        return nil
      end

      result = response.body
      {
        city: result["city"],
        region: result["region"],
        country: result["country"],
        latitude: result["lat"]&.to_f,
        longitude: result["lng"]&.to_f
      }
    rescue => e
      Rails.logger.error "Hack Club Geocoder request failed: #{e.message}"
      nil
    end

    private

    def conn
      @conn ||= Faraday.new(url: API_URL) do |faraday|
        faraday.request :url_encoded
        faraday.adapter Faraday.default_adapter
        faraday.response :json
      end
    end
  end
end
