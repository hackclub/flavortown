class LapseService
  def self.fetch_timelapses_for_project(hackatime_user_id:, project_key:)
    Rails.logger.info "LapseService: Fetching timelapses for hackatimeUserId=#{hackatime_user_id}, projectKey=#{project_key}"

    unless base_url.present?
      Rails.logger.info "LapseService: LAPSE_API_BASE not configured, skipping"
      return nil
    end

    url = "#{base_url}/hackatime/timelapsesForProject?hackatimeUserId=#{hackatime_user_id}&projectKey=#{project_key}"
    Rails.logger.info "LapseService: Requesting #{url}"

    response = connection.get("hackatime/timelapsesForProject") do |req|
      req.params["hackatimeUserId"] = hackatime_user_id
      req.params["projectKey"] = project_key
    end

    Rails.logger.info "LapseService: Response status=#{response.status}"

    if response.success?
      data = JSON.parse(response.body)
      Rails.logger.info "LapseService: Response ok=#{data['ok']}, timelapse_count=#{data.dig('data', 'timelapses')&.length || 0}"

      return nil unless data["ok"]

      data.dig("data", "timelapses") || []
    else
      Rails.logger.error "LapseService error: #{response.status} - #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "LapseService exception: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    nil
  end

  def self.fetch_all_timelapses_for_projects(hackatime_user_id:, project_keys:)
    timelapses = []

    project_keys.each do |project_key|
      result = fetch_timelapses_for_project(
        hackatime_user_id: hackatime_user_id,
        project_key: project_key
      )
      timelapses.concat(result) if result.present?
    end

    timelapses
  end

  class << self
    private

    def base_url
      ENV["LAPSE_API_BASE"]
    end

    def connection
      @connection ||= Faraday.new(url: base_url) do |conn|
        conn.headers["Content-Type"] = "application/json"
        conn.headers["User-Agent"] = Rails.application.config.user_agent
      end
    end
  end
end
