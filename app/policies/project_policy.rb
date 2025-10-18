class ProjectPolicy < ApplicationPolicy
    def show?
        true
    end

    def new?
        logged_in?
    end

    def create?
        logged_in?
    end

    def edit?
        owns? || user.admin?
    end

    def update?
        owns? || user.admin?
    end

    def destroy?
        owns? || user.admin?
    end

    private

    def owns?
        return false unless user && record
        user.membership.exists?(project: record, role: "owner")
    end
end
