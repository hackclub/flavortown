class UserProfilePolicy < ApplicationPolicy
  def edit?
    user_is_owner_or_admin?
  end

  def update?
    user_is_owner_or_admin?
  end

  private

  def user_is_owner_or_admin?
    user && (user.admin? || record.user_id == user.id)
  end
end
