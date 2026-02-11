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

    raise Pundit::NotAuthorizedError, "Your voting has been locked temporarily. Please contact @Fraud Squad for more information." if user.voting_locked?
    raise Pundit::NotAuthorizedError, "You must have shipped at least one project to vote." unless user.has_shipped?
    raise Pundit::NotAuthorizedError, "Voting is currently disabled." unless Flipper.enabled?(:voting, user)

    true
  end
end
