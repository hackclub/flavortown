class CommentPolicy < ApplicationPolicy
  def create?
    logged_in? && Flipper.enabled?(:create_comments, user)
  end

  def destroy?
    logged_in? && (record.user == user || user.admin?)
  end
end
