class ReportPolicy < ApplicationPolicy
  def create?
    logged_in?
  end
end
