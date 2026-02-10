class ShipCertService
  WEBHOOK_URL = ENV["SW_DASHBOARD_WEBHOOK_URL"]
  CERT_API_KEY = ENV["SW_DASHBOARD_API_KEY"]
  USER_AGENT = "Flavortown/1.0 (ShipCertService)"

  def self.ship_data(project, type: nil, ship_event: nil)
    owner = project.memberships.owner.first&.user
    ship_event ||= latest_ship_event(project)

    devlog_count = project.devlog_posts
      .joins("JOIN post_devlogs ON post_devlogs.id = posts.postable_id")
      .where(post_devlogs: { deleted_at: nil })
      .size

    last_ship_at = project.ship_events.first&.created_at

    {
      event: "ship.submitted",
      data: {
        id: project.id.to_s,
        shipEventId: ship_event&.id&.to_s,
        projectName: project.title,
        submittedBy: {
          slackId: owner&.slack_id,
          username: owner&.display_name || "Not Found"
        },
        projectType: project.project_type,
        type: type,
        description: project.description,
        links: {
          demo: project.demo_url,
          repo: project.repo_url,
          readme: project.readme_url
        },
        metadata: {
          devTime: project.duration_seconds,
          devlogCount: devlog_count,
          lastShipEventAt: last_ship_at&.iso8601
        }
      }
    }
  end

  def self.ship_to_dash(project, type: nil, force: false)
    ship_event = latest_ship_event(project)
    return false unless ship_event

    ShipCertWebhookJob.perform_later(ship_event_id: ship_event.id, type: type, force: force)
    true
  end

  def self.send_webhook(project, type: nil, ship_event: nil)
    raise "SW_DASHBOARD_WEBHOOK_URL is not configured" unless WEBHOOK_URL.present?
    raise "SW_DASHBOARD_API_KEY is not configured" unless CERT_API_KEY.present?

    response = Faraday.post(WEBHOOK_URL) do |req|
      req.headers["Content-Type"] = "application/json"
      req.headers["User-Agent"] = USER_AGENT
      req.headers["x-api-key"] = CERT_API_KEY
      req.options.open_timeout = 5
      req.options.timeout = 10
      req.body = ship_data(project, type: type, ship_event: ship_event).to_json
    end

    if response.success?
      Rails.logger.info "#{project.id} sent for certification"
      true
    else
      # Check for duplicate ship error (403)
      if response.status == 403 && response.body.include?("duplicate ship")
        Rails.logger.warn "Duplicate ship detected for project #{project.id}"
        raise DuplicateShipError, "Project #{project.id} is already in the certification queue"
      end

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

class DuplicateShipError < StandardError; end
