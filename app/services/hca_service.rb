require "faraday"
require "json"

module HCAService
  class Error < StandardError; end

  module_function

  def host
    if Rails.env.production?
      "https://auth.hackclub.com"
    else
      "https://hca.dinosaurbbq.org"
    end
  end

  def backend_url(path = "")
    "#{host}/backend#{path}"
  end

  def me(access_token)
    raise ArgumentError, "access_token is required" if access_token.blank?

    response = connection.get("/api/v1/me") do |req|
      req.headers["Authorization"] = "Bearer #{access_token}"
      req.headers["Accept"] = "application/json"
    end

    unless response.success?
      Rails.logger.warn("HCA /me fetch failed with status #{response.status}")
      return nil
    end

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.warn("HCA /me fetch error: #{e.class}: #{e.message}")
    nil
  end

  def identity(access_token)
    result = me(access_token)
    result&.dig("identity") || {}
  end

  def portal_url(path, return_to:)
    uri = URI.join(host, "/portal/#{path}")
    uri.query = { return_to: return_to }.to_query
    uri.to_s
  end

  def address_portal_url(return_to:)
    portal_url("address", return_to:)
  end

  def verify_portal_url(return_to:)
    portal_url("verify", return_to:)
  end

  def connection
    @connection ||= Faraday.new(url: host)
  end
end
