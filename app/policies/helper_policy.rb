class HelperPolicy < ApplicationPolicy
  def access?
    user&.helper? || user&.admin? || user&.fraud_dept?
  end

  def access_helper_dashboard?
    user.helper?
  end

  def view_users?
    access?
  end

  def view_projects?
    access?
  end

  def view_shop_orders?
    access?
  end
end
