class GitCommitSyncJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    GitCommitSyncService.sync_all!
  end
end
