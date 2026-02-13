require "test_helper"

class ProjectPolicyTest < ActiveSupport::TestCase
  test "project certifier can confirm and request recertification without membership" do
    user = users(:two)
    user.granted_roles = [ "project_certifier" ]

    policy = ProjectPolicy.new(user, projects(:one))

    assert policy.confirm_recertification?
    assert policy.request_recertification?
  end

  test "non-member without certifier role cannot confirm or request recertification" do
    policy = ProjectPolicy.new(users(:two), projects(:one))

    assert_not policy.confirm_recertification?
    assert_not policy.request_recertification?
  end
end
