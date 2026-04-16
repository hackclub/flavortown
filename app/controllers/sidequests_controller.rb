class SidequestsController < ApplicationController
  def index
    @active_sidequests = Sidequest.active.with_approved_count
    @expired_sidequests = Sidequest.expired.with_approved_count
  end

  def show
    @sidequest = Sidequest.find_by!(slug: params[:id])

    if @sidequest.external_page_link.present?
      redirect_to @sidequest.external_page_link, allow_other_host: true and return
    end

    @approved_entries = @sidequest.sidequest_entries
      .approved
      .joins(:project)
      .includes(project: :memberships)
    if @sidequest.slug == "webos"
      @prizes = ShopItem.where("? = ANY(requires_achievement)", "sidequest_webos").where(enabled: true)
    end

    if @sidequest.slug == "optimization"
      @prizes = ShopItem.where("? = ANY(requires_achievement)", "sidequest_optimization").where(enabled: true)
    end

    if @sidequest.slug == "lockin"
      @prizes = ShopItem.where("? = ANY(requires_achievement)", "sidequest_lockin").where(enabled: true)
    end

    if @sidequest.slug == "rusty-frontend"
      @prizes = ShopItem.where("? = ANY(requires_achievement)", "sidequest_rusty_frontend").where(enabled: true)
    end

    if @sidequest.slug == "caffeinated"
      @prizes = ShopItem.where("? = ANY(requires_achievement)", "sidequest_caffeinated").where(enabled: true)
    end

    if @sidequest.slug == "minecraft-art"
      @prizes = ShopItem.where("? = ANY(requires_achievement)", "sidequest_minecraft-art").where(enabled: true)
    end

    custom_template = "sidequests/show_#{@sidequest.slug}"
    if lookup_context.exists?(custom_template)
      render custom_template
    end
  end

  def generate_ideas
    api_key = ENV['GEMINI_API_KEY']
    
    if api_key.blank?
      render json: { idea: "Missing GEMINI_API_KEY in .env file." }
      return
    end

    require 'net/http'
    require 'uri'
    require 'json'
    
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemma-3-27b-it:generateContent?key=#{api_key}")
    
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request.body = JSON.dump({
      "contents" => [{"role" => "user", "parts" => [{"text" => "Provide 1 cool Minecraft sidequest idea that involves coding (like a minecraft shader with retro vibe, or a custom plugin). Give me a mix of creative ideas, but output just ONE specific prompt/idea right now. Keep it short, maximum 2 sentences."}]}]
    })
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
    
    begin
      result = JSON.parse(response.body)
      if response.code == "200"
        text = result.dig("candidates", 0, "content", "parts", 0, "text") || "Could not generate ideas right now."
        render json: { idea: text.strip }
      else
        render json: { idea: "API Error: #{result.dig('error', 'message')}" }
      end
    rescue
      render json: { idea: "Failed to parse API response." }
    end
  end
end
