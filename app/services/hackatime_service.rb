class HackatimeService
  BASE_URL = "https://hackatime.hackclub.com/api/v1"
  START_DATE = "2025-11-05"
  # fetch projects agnostic of slack id or hackatime uid
  def self.fetch_user_projects(identifier)
    url = "#{BASE_URL}/users/#{identifier}/stats?features=projects&start_date=#{START_DATE}"

    response = Faraday.get(url) do |req|
      req.headers["Content-Type"] = "application/json"
    end

    if response.success?
      data = JSON.parse(response.body)
      projects = data.dig("data", "projects") || []
      projects.map { |p| p["name"] }.reject { |name| User::HackatimeProject::EXCLUDED_NAMES.include?(name) }
    else
      Rails.logger.error "HackatimeService error: #{response.status} - #{response.body}"
      []
    end
  rescue => e
    Rails.logger.error "HackatimeService exception: #{e.message}"
    []
  end

  def self.fetch_user_projects_with_time(identifier)
    url = "#{BASE_URL}/users/#{identifier}/stats?features=projects&start_date=#{START_DATE}"

    response = Faraday.get(url) do |req|
      req.headers["Content-Type"] = "application/json"
    end

    if response.success?
      data = JSON.parse(response.body)
      projects = data.dig("data", "projects") || []
      projects.reject { |p| User::HackatimeProject::EXCLUDED_NAMES.include?(p["name"]) }
               .to_h { |p| [ p["name"], p["total_seconds"].to_i ] }
    else
      Rails.logger.error "HackatimeService error: #{response.status} - #{response.body}"
      {}
    end
  rescue => e
    Rails.logger.error "HackatimeService exception: #{e.message}"
    {}
  end

  def self.sync_user_projects(user, identifier)
    project_names = fetch_user_projects(identifier)

    project_names.each do |name|
      user.hackatime_projects.find_or_create_by!(name: name)
    end
  rescue => e
    Rails.logger.error "Failed to sync Hackatime projects for user #{user.id}: #{e.message}"
  end
end
