module Admin
  class SupportVibesController < Admin::ApplicationController
    def index
      authorize :admin, :access_support_vibes?
      @vibes = SupportVibes.order(period_end: :desc).limit(20)
    end

    def create
      authorize :admin, :access_support_vibes?
      
      last_vibe = SupportVibes.order(period_end: :desc).first
      start_time = last_vibe ? last_vibe.period_end : 24.hours.ago
      end_time = Time.current

      begin
        response = Faraday.get("https://flavortown.nephthys.hackclub.com/api/tickets") do |req|
          req.params['after'] = start_time.iso8601
          req.params['before'] = end_time.iso8601
        end 

        unless response.success?
          redirect_to admin_support_vibes_path, alert: "Failed to fetch data from Nephthys."
          return
        end 

        tickets = JSON.parse(response.body)

        if tickets.empty?
          redirect_to admin_support_vibes_path, notice: "No new tickets found in the specified time frame."
          return
        end

        questions_list = tickets.map { |t| t["description"].to_s }
        questions = questions_list.map.with_index(1) { |q, i| "#{i}. #{q}" }.join("\n")

        prompt = <<~PROMPT
          Analyze the following support questions and summarize the current vibes.

          Questions:
          #{questions}

          Return ONLY a valid JSON object with the following structure (no markdown formatting, no code blocks): 
          {
            "top_5_concerns": ["concern 1", "concern 2", ...],
            "overall_sentiment": 0.5, // Float between -1.0 (very negative) and 1.0 (very positive)
            "rating": "medium", // Must be one of: "low", "medium", "high". "high" means good vibes (happy users).
            "notable_quotes": ["quote 1", "quote 2", ...] // Extract 2-3 short, impactful quotes VERBATIM from the descriptions.
          }
        PROMPT

        llm_response = Faraday.post("https://ai.hackclub.com/proxy/v1/chat/completions") do |req|
          req.headers['Authorization'] = "Bearer #{ENV['HCAI_API_KEY']}"
          req.headers['Content-Type'] = 'application/json'
          req.body = {
            model: "x-ai/grok-4.1-fast",
            messages: [
              { role: "user", content: prompt }
            ]
          }.to_json
        end

        unless llm_response.success?
          Rails.logger.error "LLM Failure: #{llm_response.status} body: #{llm_response.body}"
          redirect_to admin_support_vibes_path, alert: "LLM response failed."
          return
        end

        llm_body = JSON.parse(llm_response.body)
        content = llm_body.dig("choices", 0, "message", "content")

        # # Remove code blocks (if present, idk)
        cleaned_content = content.gsub(/^```json\s*|```\s*$/, "")
        llm_result = JSON.parse(cleaned_content)

        SupportVibes.create!(
          period_start: start_time,
          period_end: end_time,
          concerns: llm_result["top_5_concerns"],
          overall_sentiment: llm_result["overall_sentiment"],
          notable_quotes: llm_result["notable_quotes"],
          rating: llm_result["rating"]
        )

        redirect_to admin_support_vibes_path, notice: "Support vibes updated successfully."
      
      rescue JSON::ParserError
        redirect_to admin_support_vibes_path, alert: "Received invalid JSON from Nephthys."
      rescue StandardError => e
        redirect_to admin_support_vibes_path, alert: "An error occurred: #{e.message}"
      end
    end
  end
end