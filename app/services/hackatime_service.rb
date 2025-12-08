class HackatimeService
  BASE_URL = "https://hackatime.hackclub.com/api/v1"
  START_DATE = "2025-11-05"

  def self.fetch_user_projects(identifier, user: nil)
    url = "#{BASE_URL}/users/#{identifier}/stats?features=projects&start_date=#{START_DATE}"

    response = Faraday.get(url) do |req|
      req.headers["Content-Type"] = "application/json"
    end

    if response.success?
      data = JSON.parse(response.body)
      check_and_ban_if_hackatime_banned(data, user) if user
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

  def self.fetch_user_projects_with_time(identifier, user: nil)
    url = "#{BASE_URL}/users/#{identifier}/stats?features=projects&start_date=#{START_DATE}"

    response = Faraday.get(url) do |req|
      req.headers["Content-Type"] = "application/json"
    end

    if response.success?
      data = JSON.parse(response.body)
      check_and_ban_if_hackatime_banned(data, user) if user
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

  def self.check_and_ban_if_hackatime_banned(data, user)
    return unless user && !user.banned?

    is_banned = data.dig("trust_factor", "trust_value") == 1
    return unless is_banned

    Rails.logger.warn "HackatimeService: User #{user.id} (#{user.slack_id}) is banned on Hackatime, auto-banning"
    user.ban!(reason: "Automatically banned: User is banned on Hackatime")
  end

  def self.sync_user_projects(user, identifier)
    project_names = fetch_user_projects(identifier, user: user)

    project_names.each do |name|
      user.hackatime_projects.find_or_create_by!(name: name)
    end
  rescue => e
    Rails.logger.error "Failed to sync Hackatime projects for user #{user.id}: #{e.message}"
  end
end
