require "test_helper"

class AdminPolicyTest < Minitest::Test
  UserStub = Struct.new(:admin_access, :super_admin_access, :flavortime_access) do
    def admin? = admin_access
    def super_admin? = super_admin_access
    def flavortime? = flavortime_access
  end

  def test_flavortime_dashboard_access_for_admin
    policy = AdminPolicy.new(UserStub.new(true, false, false), :admin)

    assert policy.access_flavortime_dashboard?
  end

  def test_flavortime_dashboard_access_for_flavortime_role
    policy = AdminPolicy.new(UserStub.new(false, false, true), :admin)

    assert policy.access_flavortime_dashboard?
  end

  def test_flavortime_dashboard_denied_without_required_role
    policy = AdminPolicy.new(UserStub.new(false, false, false), :admin)

    refute policy.access_flavortime_dashboard?
  end
end
