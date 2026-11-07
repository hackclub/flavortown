class PruneActiveInsightsJob < ApplicationJob
  queue_as :literally_whenever

  RETENTION = 30.days

  def perform
    cutoff = RETENTION.ago

    [ ActiveInsights::Request, ActiveInsights::Job ].each do |model|
      model.where(started_at: ...cutoff).in_batches(of: 10_000).delete_all
    end
  end
end
