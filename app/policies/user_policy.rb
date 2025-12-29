class UserPolicy < ApplicationPolicy
  def show?
    true
  end

  def impersonate?
    # must be admin or super_admin to impersonate
    return false unless user.admin? || user.super_admin?

    # cannot impersonate yourself
    return false if user.id == record.id

    # only super admins can impoersonate admins
    if record.admin? && !user.super_admin?
      return false
    end

    true
  end
end
