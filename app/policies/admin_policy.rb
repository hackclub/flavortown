class AdminPolicy < ApplicationPolicy
    def blazer?
      user.try(:admin?)
    end
  
    def flipper?
      user.try(:admin?)
    end
  
    def access_admin_endpoints?
      user.try(:admin?) || user.try(:fraud_dept)
    end
  end
  