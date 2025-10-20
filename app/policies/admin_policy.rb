class AdminPolicy < ApplicationPolicy
    def blazer?
      user.try(:admin?)
    end
  
    def flipper?
      user.try(:admin?)
    end
    def users?
      user&.admin? || user&.fraud_dept?
    end
    def projects?
      user&.admin? || user&.fraud_dept?
    end
    def access_admin_endpoints?
      user&.admin? || user&.fraud_dept?
    end
  end
  