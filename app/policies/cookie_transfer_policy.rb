class CookieTransferPolicy < ApplicationPolicy
  def new?
    logged_in? && !user.banned?
  end

  def create?
    new?
  end
end
