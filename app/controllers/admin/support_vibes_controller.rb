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

        # Sample llm result so i can fix layout a bit
        llm_result = {
          "top_5_concerns" => [
            "Hardware shipment delays in EU",
            "Confusion about 'Shadow Banned' status", 
            "Login issues with magic link",
            "Users asking for more stickers",
            "Bug in project submission form"
          ],
          "overall_sentiment" => -0.25,
          "notable_quotes" => [
            "I've been waiting for my PCB for 3 weeks!",
            "This platform is actually really cool despite the bugs.",
            "Why can't I vote on my own project?"
          ],
          "rating" => "medium" 
        }

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