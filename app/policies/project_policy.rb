class ProjectPolicy < ApplicationPolicy
    def index?
        logged_in?
    end

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
        owns? || user&.admin?
    end

    def update?
        owns? || user&.admin?
    end

    def destroy?
        owns? || user&.admin?
    end

    def ship?
        member?
    end

    def update_ship?
        member?
    end

    def submit_ship?
        member?
    end

    private

    def member?
        return false unless user && record
        user.memberships.exists?(project: record)
    end

    def owns?
        return false unless user && record
        user.memberships.exists?(project: record, role: "owner")
    end
end
