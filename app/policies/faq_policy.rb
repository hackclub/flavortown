class FaqPolicy < ApplicationPolicy
  def index?
    logged_in?
  end
end
