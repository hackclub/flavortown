class AnthropicApiService
  def self.call(prompt)
    new.call(prompt)
  end

  def call(prompt)
    uri = URI("https://api.anthropic.com/v1/messages")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(uri)
    request["x-api-key"] = ENV['ANTHROPIC_API_KEY']
    request["Content-Type"] = "application/json"
    request["anthropic-version"] = "2023-06-01"
    
    request.body = {
      model: "claude-3-haiku-20240307",
      max_tokens: 1000,
      messages: [{ role: "user", content: prompt }]
    }.to_json

    response = http.request(request)
    json = JSON.parse(response.body)
    json.dig("content", 0, "text")
  end
end
