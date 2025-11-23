class AdminPolicy < ApplicationPolicy
    def access_blazer?
      user.admin?
    end

    def access_flipper?
      user.admin?
    end

    def manage_users?
      user.admin? || user.fraud_dept?
    end

    def manage_projects?
      user.admin? || user.fraud_dept?
    end

    def access_admin_endpoints?
      user.admin? || user.fraud_dept?
    end

    def manage_user_roles?
      user.admin?
    end

    def access_jobs?
      user.admin?
    end

    def manage_shop?
      user.admin?
    end

    def access_audit_logs?
      user.admin?
    end

    def shop_orders?
      user.admin? || user.fraud_dept?
    end

    def access_fulfillment_view?
      user.admin? || user.fulfillment_person?
    end
     def access_shop_orders?
      user.admin? || user.fraud_dept?
    end

end
