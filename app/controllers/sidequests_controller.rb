class SidequestsController < ApplicationController
  def index
    @active_sidequests = ordered_sidequests(Sidequest.active.with_approved_count)
    @expired_sidequests = ordered_sidequests(Sidequest.expired.with_approved_count)
  end

  def show
    requested_slug = params[:id].to_s
    @sidequest = Sidequest.find_by(slug: requested_slug)
    minequest_alias_slugs = [ "minequest", "minequests", "minecraft-art" ]

    if @sidequest.nil? && minequest_alias_slugs.include?(requested_slug)
      @sidequest = Sidequest.where(slug: minequest_alias_slugs)
        .or(Sidequest.where("LOWER(title) LIKE ?", "%minequest%"))
        .or(Sidequest.where("LOWER(title) LIKE ?", "%minecraft%"))
        .order(Arel.sql("CASE WHEN sidequests.slug = 'minequest' THEN 0 WHEN sidequests.slug = 'minequests' THEN 1 WHEN sidequests.slug = 'minecraft-art' THEN 2 ELSE 3 END"))
        .first
    end

    raise ActiveRecord::RecordNotFound if @sidequest.nil?

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

    is_minequest = [ "minequest", "minequests" ].include?(requested_slug) ||
      minequest_alias_slugs.include?(@sidequest.slug) ||
      @sidequest.title == "Minequest" ||
      @sidequest.title.to_s.downcase.include?("minecraft")

    if is_minequest
      achievement_keys = [ "sidequest_minequest", "sidequest_minecraft_art", "sidequest_minecraft-art" ]
      @prizes = ShopItem.where("requires_achievement && ARRAY[?]::varchar[]", achievement_keys).where(enabled: true)
      if params[:view] != "submissions"
        render "sidequests/minequest/show" and return
      end
      @display_title = "Minequest"
    end

    if @sidequest.slug == "transcode"
      @prizes = ShopItem.where("? = ANY(requires_achievement)", "sidequest_transcode").where(enabled: true)
    end

    if @sidequest.slug == "kernel"
      @prizes = ShopItem.where("? = ANY(requires_achievement)", "sidequest_kernel").where(enabled: true)
    end

    custom_template = "sidequests/show_#{@sidequest.slug}"
    if lookup_context.exists?(custom_template)
      render custom_template
    end
  end

  def generate_ideas
    unless ENV["OPENAI_API_KEY"].present?
      render json: { idea: "Missing OPENAI_API_KEY in .env file." }
      return
    end

    requested_exclusions = begin
      payload = request.request_parameters
      payload = JSON.parse(request.raw_post) if payload.blank? && request.raw_post.present?
      Array(payload["exclude_ideas"]).map { |idea| idea.to_s.strip }.reject(&:blank?).first(10)
    rescue JSON::ParserError
      []
    end

    exclusion_prompt = if requested_exclusions.any?
      "Avoid repeating any of these prior ideas exactly or semantically:\n- #{requested_exclusions.join("\n- ")}"
    else
      ""
    end

    prompt = <<~PROMPT
      Generate exactly one Minecraft coding sidequest idea.
      Return valid JSON only with keys: idea, difficulty, time_estimate.
      difficulty must be one of: Easy, Medium, Hard.
      time_estimate should be a concise range like "2-4 hours" or "1-2 days".
      idea should be short (max 2 sentences) and specific.
      #{exclusion_prompt}
    PROMPT

    api_response = OpenaiApiService.call(prompt)

    if api_response.present?
      parsed = parse_idea_payload(api_response)

      if parsed.present?
        render json: {
          idea: parsed["idea"].presence || "Could not generate ideas right now.",
          difficulty: parsed["difficulty"].presence || "Medium",
          time_estimate: parsed["time_estimate"].presence || "2-4 hours"
        }
      else
        render json: {
          idea: api_response.strip.presence || "Could not generate ideas right now.",
          difficulty: "Medium",
          time_estimate: "2-4 hours"
        }
      end
    else
      render json: { idea: "Failed to generate ideas.", difficulty: "Unknown", time_estimate: "Unknown" }
    end
  end

  private

  def parse_idea_payload(text)
    direct = begin
      JSON.parse(text)
    rescue JSON::ParserError
      nil
    end
    return direct if direct.is_a?(Hash)

    fenced = text.match(/```(?:json)?\s*(\{.*?\})\s*```/m)&.captures&.first
    fenced_parsed = begin
      JSON.parse(fenced)
    rescue JSON::ParserError, TypeError
      nil
    end
    return fenced_parsed if fenced_parsed.is_a?(Hash)

    inline = text.match(/\{.*\}/m)&.to_s
    inline_parsed = begin
      JSON.parse(inline)
    rescue JSON::ParserError, TypeError
      nil
    end
    return inline_parsed if inline_parsed.is_a?(Hash)

    nil
  end

  def ordered_sidequests(scope)
    scope.order(Arel.sql("CASE WHEN sidequests.slug IN ('minequest', 'minequests', 'minecraft-art') OR sidequests.title IN ('Minequest', 'Minecraft Art Challenge') THEN 0 ELSE 1 END"), :title)
  end
end
