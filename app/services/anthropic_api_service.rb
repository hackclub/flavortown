class AnthropicApiService < AiService
  private

  def api_endpoint
    "https://api.anthropic.com/v1/messages"
  end

  def headers
    {
      "x-api-key" => ENV["ANTHROPIC_API_KEY"],
      "Content-Type" => "application/json",
      "anthropic-version" => "2023-06-01"
    }
  end

  def request_body(prompt)
    {
      model: "claude-3-haiku-20240307",
      max_tokens: 1000,
      messages: [ { role: "user", content: prompt } ]
    }
  end

  def extract_content(json)
    json.dig("content", 0, "text")
  end
end
