# Override ActiveInsights to batch writes instead of writing immediately.
#
# By default, ActiveInsights spawns a thread for each request and calls create!
# for each job synchronously. Under load, this causes massive I/O spikes as all
# these writes hit the database at once.
#
# This initializer replaces the default subscribers with buffered versions that
# collect insights in memory and flush them in batches via a background job.

Rails.application.config.after_initialize do
  # Only enable batching in production
  next unless Rails.env.production?

  # Unsubscribe from the original ActiveInsights subscribers
  ActiveSupport::Notifications.unsubscribe("process_action.action_controller")
  ActiveSupport::Notifications.unsubscribe("perform.active_job")

  # Re-subscribe with buffered versions
  ActiveSupport::Notifications.subscribe("process_action.action_controller") do |_name, started, finished, unique_id, payload|
    next if ActiveInsights.ignored_endpoint?(payload) || !ActiveInsights.enabled?

    req = payload[:request]

    attributes = {
      started_at: started,
      finished_at: finished,
      uuid: unique_id,
      ip_address: req.remote_ip,
      http_method: payload[:method],
      user_agent: req.user_agent.to_s.first(255),
      controller: payload[:controller],
      action: payload[:action],
      format: payload[:format],
      status: payload[:status],
      view_runtime: payload[:view_runtime],
      db_runtime: payload[:db_runtime],
      path: payload[:path]
    }

    InsightsBuffer.instance.push_request(attributes)
  end

  ActiveSupport::Notifications.subscribe("perform.active_job") do |_name, started, finished, unique_id, payload|
    next unless ActiveInsights.enabled?
    # Skip recording the flush job itself to avoid infinite loop
    next if payload[:job].class.name == "FlushInsightsBufferJob"

    attributes = {
      started_at: started,
      finished_at: finished,
      uuid: unique_id,
      db_runtime: payload[:db_runtime],
      job: payload[:job].class.to_s,
      queue: payload[:job].queue_name,
      scheduled_at: payload[:job].scheduled_at
    }

    InsightsBuffer.instance.push_job(attributes)
  end

  Rails.logger.info "[ActiveInsights] Batched recording enabled (max buffer: #{InsightsBuffer::MAX_BUFFER_SIZE}, flush interval: #{InsightsBuffer::FLUSH_INTERVAL_SECONDS}s)"

  # Flush buffer on shutdown to avoid data loss
  at_exit do
    Rails.logger.info "[ActiveInsights] Flushing buffer on shutdown..."
    InsightsBuffer.instance.flush!
  end
end
