class AdminPolicy < ApplicationPolicy
    def blazer?
      user.try(:is_admin)
    end
  
    def flipper?
      user.try(:is_admin)
    end
  
    def access_admin_endpoints?
      user.try(:is_admin) || user.try(:is_fraud_dept)
    end
  end
  