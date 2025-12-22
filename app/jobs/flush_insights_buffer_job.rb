# Flushes the InsightsBuffer to the database in batches.
# This job runs periodically to ensure buffered insights are persisted.
class FlushInsightsBufferJob < ApplicationJob
  queue_as :low

  # Skip duplicate jobs - only one flush needs to run at a time
  limits_concurrency to: 1, key: -> { "flush_insights_buffer" }

  def perform
    InsightsBuffer.instance.flush!
  end
end
