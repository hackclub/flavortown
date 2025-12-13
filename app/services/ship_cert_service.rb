require "net/http"
require "json"

class ShipCertService
  WEBHOOK_URL = ENV["SW_DASHBOARD_WEBHOOK_URL"]
  CERT_API_KEY = ENV["SW_DASHBOARD_API_KEY"]

  def self.ship_data(project)
    owner = project.memberships.owner.first&.user

    {
      event: 'ship.submitted',
      data: {
        id: project.id.to_s,
        projectName: project.title,
        submittedBy: {
          slackId: owner&.slack_id,
          username: owner&.display_name || "Not Found"
        },
        projectType: project.project_type,
        description: project.description,
        links: {
          demo: project.demo_url,
          repo: project.repo_url,
          readme: project.readme_url
        },
        metadata: {
          devTime: project.time ? "#{project.time.hours}h #{project.time.minutes}m" : nil
        }
      }
    }
  end

  def self.ship_to_dash(project)
    return false unless WEBHOOK_URL.present?
    return false unless CERT_API_KEY.present?

    uri = URI(WEBHOOK_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.path, {
      'Content-Type' => 'application/json',
      'x-api-key' => CERT_API_KEY
    })
    request.body = self.ship_data(project).to_json

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      Rails.logger.info "#{project.id} sent for certification"
      true
    else
      Rails.logger.error "cert request failed: #{response.body}"
      false
    end
  rescue => e
    Rails.logger.error "cert request error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
    false
  end

end