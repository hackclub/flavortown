class OpenaiApiService
  def self.call(prompt)
    new.call(prompt)
  end

  def call(prompt)
    uri = URI("https://api.openai.com/v1/chat/completions")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{ENV['OPENAI_API_KEY']}"
    request["Content-Type"] = "application/json"
    
    request.body = {
      model: "gpt-4o-mini",
      messages: [{ role: "user", content: prompt }]
    }.to_json

    response = http.request(request)
    json = JSON.parse(response.body)
    json.dig("choices", 0, "message", "content")
  end
end
