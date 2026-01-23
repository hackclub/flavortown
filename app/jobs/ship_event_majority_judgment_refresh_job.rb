class ShipEventMajorityJudgmentRefreshJob < ApplicationJob
  queue_as :default

  def perform
    MajorityJudgmentService.refresh_all!
  end
end
