class VotePolicy < ApplicationPolicy
  def index?
    logged_in?
  end

  def new?
    logged_in?
  end

  def create?
    logged_in?
  end
end
