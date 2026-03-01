class OneTime::HackatimeTimeLossAuditJob < ApplicationJob
  queue_as :default

  THROTTLE_DELAY = 0.25 # seconds between API calls to avoid overwhelming Hackatime

  def perform
    Rails.logger.info "[HackatimeTimeLossAudit] Starting audit..."

    HackatimeTimeLossAudit.delete_all

    audited = 0
    skipped = 0
    failed = 0
    audited_at = Time.current

    # Group projects by owner to avoid duplicate fetch_stats calls for the same user
    owner_projects = {}

    Project.includes(:hackatime_projects, memberships: [ :user, user: :identities ]).find_each do |project|
      hackatime_projects = project.hackatime_projects.to_a
      next if hackatime_projects.empty?

      owner = project.memberships.find { |m| m.role == "owner" }&.user
      next unless owner

      hackatime_uid = owner.hackatime_identity&.uid
      next unless hackatime_uid

      owner_projects[hackatime_uid] ||= { user: owner, projects: [] }
      owner_projects[hackatime_uid][:projects] << { project: project, keys: hackatime_projects.map(&:name) }
    end

    Rails.logger.info "[HackatimeTimeLossAudit] Found #{owner_projects.size} unique users with #{owner_projects.values.sum { |v| v[:projects].size }} eligible projects"

    owner_projects.each do |hackatime_uid, data|
      owner = data[:user]

      # One fetch_stats call per user (not per project)
      stats = HackatimeService.fetch_stats(hackatime_uid)
      unless stats
        failed += data[:projects].size
        next
      end
      sleep(THROTTLE_DELAY)

      data[:projects].each do |entry|
        project = entry[:project]
        keys = entry[:keys]

        per_project_sum = keys.sum { |key| stats[:projects][key].to_i }

        ungrouped_total = fetch_ungrouped_total(hackatime_uid, keys)
        if ungrouped_total.nil?
          failed += 1
          next
        end
        sleep(THROTTLE_DELAY)

        devlog_total = project.calculate_duration_seconds
        difference = per_project_sum - ungrouped_total

        HackatimeTimeLossAudit.create!(
          project: project,
          user: owner,
          per_project_sum_seconds: per_project_sum,
          ungrouped_total_seconds: ungrouped_total,
          devlog_total_seconds: devlog_total,
          difference_seconds: difference,
          hackatime_keys: keys.join(","),
          audited_at: audited_at
        )

        audited += 1
        Rails.logger.info "[HackatimeTimeLossAudit] Project #{project.id} (#{project.title}): diff=#{difference}s (#{(difference / 3600.0).round(2)}h)"
      rescue => e
        failed += 1
        Rails.logger.error "[HackatimeTimeLossAudit] Error for project #{project.id}: #{e.message}"
      end
    rescue => e
      failed += data[:projects].size
      Rails.logger.error "[HackatimeTimeLossAudit] Error for user #{hackatime_uid}: #{e.message}"
    end

    Rails.logger.info "[HackatimeTimeLossAudit] Complete. audited=#{audited}, skipped=#{skipped}, failed=#{failed}"
  end

  private

  def fetch_ungrouped_total(hackatime_uid, keys)
    params = {
      features: "projects",
      start_date: HackatimeService::START_DATE,
      test_param: true,
      total_seconds: true,
      filter_by_project: keys.join(",")
    }

    response = hackatime_connection.get("users/#{hackatime_uid}/stats", params)

    if response.success?
      data = JSON.parse(response.body)
      data["total_seconds"].to_i
    else
      Rails.logger.error "[HackatimeTimeLossAudit] API error: #{response.status} - #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "[HackatimeTimeLossAudit] API exception: #{e.message}"
    nil
  end

  def hackatime_connection
    @hackatime_connection ||= Faraday.new(url: "#{HackatimeService::BASE_URL}/api/v1") do |conn|
      conn.headers["Content-Type"] = "application/json"
      conn.headers["User-Agent"] = Rails.application.config.user_agent
      conn.headers["RACK_ATTACK_BYPASS"] = ENV["HACKATIME_BYPASS_KEYS"] if ENV["HACKATIME_BYPASS_KEYS"].present?
      conn.options.timeout = 30
      conn.options.open_timeout = 10
    end
  end
end
