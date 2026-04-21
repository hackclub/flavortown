class User::RefreshVerdictsJob < ApplicationJob
  queue_as :default

  def perform
    Secrets::VoteVerdictRefresh.call
  end
end
