class ShipCertService
  WEBHOOK_URL = ENV["SW_DASHBOARD_WEBHOOK_URL"]
  CERT_API_KEY = ENV["SW_DASHBOARD_API_KEY"]
  USER_AGENT = "Flavortown/1.0 (ShipCertService)"

  def self.ship_data(project)
    owner = project.memberships.owner.first&.user

    {
      event: "ship.submitted",
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
          devTime: project.duration_seconds
        }
      }
    }
  end

  def self.ship_to_dash(project)
    raise "SW_DASHBOARD_WEBHOOK_URL is not configured" unless WEBHOOK_URL.present?
    raise "SW_DASHBOARD_API_KEY is not configured" unless CERT_API_KEY.present?

    response = Faraday.post(WEBHOOK_URL) do |req|
      req.headers["Content-Type"] = "application/json"
      req.headers["User-Agent"] = USER_AGENT
      req.headers["x-api-key"] = CERT_API_KEY
      req.options.open_timeout = 5
      req.options.timeout = 10
      req.body = ship_data(project).to_json
    end

    if response.success?
      Rails.logger.info "#{project.id} sent for certification"
      true
    else
      raise "Certification request failed for project #{project.id}: #{response.body}"
    end
  rescue Faraday::Error => e
    Rails.logger.error "cert request error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
    raise e
  end

  def self.get_status(project)
    ship_event = latest_ship_event(project)
    return nil unless ship_event

    ship_event.certification_status
  end

  def self.get_feedback(project)
    ship_event = latest_ship_event(project)
    return nil unless ship_event

    {
      status: ship_event.certification_status,
      video_url: ship_event.feedback_video_url,
      reason: ship_event.feedback_reason
    }
  end

  def self.latest_ship_event(project)
    project.ship_events.first
  end
end
