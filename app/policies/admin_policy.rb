class AdminPolicy < ApplicationPolicy
    def blazer?
      user.is_admin?
    end
  
    def flipper?
      user.is_admin?
    end
  
    def access_admin_endpoints?
      user.is_admin? || user.is_fraud_dept?
    end
  end
  