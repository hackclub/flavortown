class RecalculateProjectDurationsJob < ApplicationJob
  queue_as :default

  def perform
    Project.find_each(&:recalculate_duration_seconds!)
  end
end
