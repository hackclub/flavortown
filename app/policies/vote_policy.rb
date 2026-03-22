class VotePolicy < ApplicationPolicy
  def index?
    user_can_vote?
  end

  def new?
    user_can_vote?
  end

  def create?
    user_can_vote?
  end

  private

  def user_can_vote?
    return true if user&.admin?
    raise Pundit::NotAuthorizedError, "You are not authorized to perform this action." unless user&.verification_verified?

    raise Pundit::NotAuthorizedError, "Your voting has been permanently locked. Please contact @Fraud Squad for more information." if user.voting_locked?

    if user.voting_on_cooldown?
      c = VotingCooldownService.new(user)
      raise Pundit::NotAuthorizedError,
        "Your voting is on cooldown for #{c.time_remaining}. " \
        "This is stage #{user.voting_cooldown_stage}/#{VotingCooldownService::MAX_STAGE}. " \
        "Vote cleanly to reduce your cooldown stage over time."
    end

    raise Pundit::NotAuthorizedError, "You must have shipped at least one project to vote." unless user.has_shipped?
    raise Pundit::NotAuthorizedError, "You've used all available votes for now. Ship again to unlock more votes." unless user.vote_balance < 0
    raise Pundit::NotAuthorizedError, "Voting is currently disabled." unless Flipper.enabled?(:voting, user)

    true
  end
end
