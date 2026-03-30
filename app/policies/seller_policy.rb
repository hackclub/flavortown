class SellerPolicy < ApplicationPolicy
  def access?
    user&.seller?
  end
end
