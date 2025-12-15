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
    user.admin? || user.verification_verified?
  end
end
