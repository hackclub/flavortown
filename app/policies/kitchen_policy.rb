class KitchenPolicy < ApplicationPolicy
  def index?
    logged_in?
  end
end

