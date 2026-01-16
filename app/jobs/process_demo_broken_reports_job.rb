class ProcessDemoBrokenReportsJob < ApplicationJob
  queue_as :default

  SLACK_RECIPIENT = "U07L45W79E1"
  PENDING_THRESHOLD = 5
  TOTAL_THRESHOLD = 15

  def perform
    projects_with_demo_broken_reports.each do |project_id, reports|
      project = Project.find_by(id: project_id)
      next unless project

      pending_reports = reports.select(&:pending?)
      total_count = reports.size

      if pending_reports.size >= PENDING_THRESHOLD
        process_pending_reports(project, pending_reports)
      end

      if total_count >= TOTAL_THRESHOLD && !already_notified?(project)
        notify_slack(project, total_count)
        mark_as_notified(project)
      end
    end
  end

  private

  def projects_with_demo_broken_reports
    Project::Report
      .where(reason: "demo_broken")
      .includes(:project)
      .group_by(&:project_id)
  end

  def process_pending_reports(project, pending_reports)
    pending_reports.first(PENDING_THRESHOLD).each do |report|
      old_status = report.status
      report.update!(status: :reviewed)

      PaperTrail::Version.create!(
        item_type: "Project::Report",
        item_id: report.id,
        event: "update",
        whodunnit: nil,
        object_changes: {
          status: [ old_status, report.status ],
          auto_processed: [ nil, "ProcessDemoBrokenReportsJob" ]
        }
      )
    end

    Rails.logger.info "[ProcessDemoBrokenReportsJob] Marked 5 reports as reviewed for project #{project.id}, re-certifying"
    ShipCertService.ship_to_dash(project)
  rescue => e
    Rails.logger.error "[ProcessDemoBrokenReportsJob] Failed to process project #{project.id}: #{e.message}"
  end

  def notify_slack(project, count)
    message = "🚨 Project '#{project.title}' (ID: #{project.id}) has #{count} demo_broken reports. Please investigate: #{Rails.application.routes.url_helpers.project_url(project, host: default_host)}"
    #  TODO: migrate to shadow ban the project and notify the fraud dept!
    SendSlackDmJob.perform_later(SLACK_RECIPIENT, message)
  end

  def already_notified?(project)
    Rails.cache.exist?(notification_cache_key(project))
  end

  def mark_as_notified(project)
    Rails.cache.write(notification_cache_key(project), true, expires_in: 7.days)
  end

  def notification_cache_key(project)
    "demo_broken_notification:#{project.id}"
  end

  def default_host
    Rails.application.config.action_mailer.default_url_options&.dig(:host) || "flavortown.hackclub.com"
  end
end
