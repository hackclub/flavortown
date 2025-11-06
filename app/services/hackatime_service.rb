class HackatimeService
  BASE_URL = "https://hackatime.hackclub.com/api/v1"

  def self.fetch_user_projects(slack_uid)
    start_date ||= 1.month.ago.strftime("%Y-%m-%d")
    url = "#{BASE_URL}/users/#{slack_uid}/stats?features=projects&start_date=#{start_date}"

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

  def self.sync_user_projects(user, slack_uid)
    project_names = fetch_user_projects(slack_uid)

    project_names.each do |name|
      user.hackatime_projects.find_or_create_by!(name: name)
    end
  rescue => e
    Rails.logger.error "Failed to sync Hackatime projects for user #{user.id}: #{e.message}"
  end
end
