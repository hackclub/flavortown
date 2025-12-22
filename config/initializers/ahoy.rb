# frozen_string_literal: true

if ENV["AHOY_DB_URL"].present?
  class Ahoy::Store < Ahoy::DatabaseStore
    def track_visit(data)
      super
      AhoyGeocodeJob.perform_later(visit.id) if ENV["GEOCODER_HC_API_KEY"].present?
    end
  end

  Ahoy.api = false
  Ahoy.geocode = false # we have our own job for this!
else
  # Disable tracking when AHOY_DB_URL is not configured
  class Ahoy::Store < Ahoy::BaseStore
    def track_visit(_data)
    end

    def track_event(_data)
    end
  end
end
