class AdminPolicy < ApplicationPolicy
    def blazer?
      user.try(:admin?) || user.try(:fraud_dept?)
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
    def access_admin_endpoints_but_ac_admin?
      user&.admin?
    end

    def user_promotion_perms?
      user&.admin?
    end
    def jobs?
      user&.admin?
    end

    def manage_shop?
      user&.admin?
    end
    def access_audit_logs?
      user&.admin?
    end
    def shop_orders?
      user&.admin? || user&.fraud_dept?
    end
    def access_shop_orders?
      user&.admin? || user&.fulfillment_person?
    end
end
