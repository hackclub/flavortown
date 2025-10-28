class OpenaiApiService < AiService
  private

  def api_endpoint
    "https://api.openai.com/v1/chat/completions"
  end

  def headers
    {
      "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}",
      "Content-Type" => "application/json"
    }
  end

  def request_body(prompt)
    {
      model: "gpt-4o-mini",
      messages: [ { role: "user", content: prompt } ]
    }
  end

  def extract_content(json)
    json.dig("choices", 0, "message", "content")
  end
end
