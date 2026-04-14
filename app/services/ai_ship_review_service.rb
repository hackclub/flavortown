class AiShipReviewService
  ENDPOINT = "https://ai.review.hackclub.com/projects/check"
  API_KEY = ENV["SWAI_KEY"]
  CACHE_TTL = 2.minutes

  def self.cache_key(project)
    "ai_ship_review/#{project.id}"
  end

  def self.fetch(project)
    Rails.cache.fetch(cache_key(project), expires_in: CACHE_TTL) do
      result = check(project) || { "valid" => true }
      Rails.logger.info "AiShipReviewService result for project #{project.id}: #{JSON.pretty_generate(result)}" if Rails.env.development?
      result
    end
  end

  def self.check(project)
    return nil unless API_KEY.present?

    response = Faraday.get(ENDPOINT) do |req|
      req.headers["Content-Type"] = "application/json"
      req.headers["X-API-Key"] = API_KEY
      req.options.open_timeout = 20
      req.options.timeout = 25
      req.body = payload(project).to_json
    end

    JSON.parse(response.body) if response.success?
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.error "AiShipReviewService error for project #{project.id}: #{e.message}"
    nil
  end

  def self.payload(project)
    {
      repo_url: project.repo_url.to_s,
      readme_url: project.readme_url.to_s,
      demo_url: project.demo_url.to_s,
      ai_declaration: project.ai_declaration.to_s,
      project_description: project.description.to_s,
      is_updated: project.posts.where(postable_type: "Post::ShipEvent").any?
    }
  end
  private_class_method :payload
end
