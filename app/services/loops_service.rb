class LoopsService
  BASE_URL = "https://loops-api-service.hackclub.dev/api"

  def self.set_event(email, event_name, user_group: "Hack Clubber")
    uri = URI("#{BASE_URL}/subscribe")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"

    request.body = {
      email: email,
      subscribeField: event_name,
      userGroup: user_group
    }.to_json

    response = http.request(request)

    case response.code
    when "200"
      JSON.parse(response.body)
    else
      Rails.logger.error "LoopsService error: #{response.code} - #{response.body}"
      { error: "Failed to set event in Loops" }
    end
  rescue => e
    Rails.logger.error "LoopsService exception: #{e.message}"
    { error: "Failed to set event in Loops" }
  end
end
