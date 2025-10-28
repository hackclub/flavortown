class GrokApiService < AiService
  private

  def api_endpoint
    "https://api.x.ai/v1/chat/completions"
  end

  def headers
    {
      "Authorization" => "Bearer #{ENV['GROK_API_KEY']}",
      "Content-Type" => "application/json"
    }
  end

  def request_body(prompt)
    {
      model: "grok-4-fast-non-reasoning",
      messages: [ { role: "user", content: prompt } ]
    }
  end

  def extract_content(json)
    json.dig("choices", 0, "message", "content")
  end
end
