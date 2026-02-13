require "test_helper"

class ProjectPolicyTest < Minitest::Test
  MembershipsStub = Struct.new(:is_member) do
    def exists?(project:)
      is_member
    end
  end

  UserStub = Struct.new(:is_certifier, :is_member) do
    def project_certifier?
      is_certifier
    end

    def memberships
      MembershipsStub.new(is_member)
    end
  end

  def test_project_certifier_can_confirm_and_request_recertification_without_membership
    user = UserStub.new(true, false)
    project = Object.new

    policy = ProjectPolicy.new(user, project)

    assert policy.confirm_recertification?
    assert policy.request_recertification?
  end

  def test_non_member_without_certifier_role_cannot_confirm_or_request_recertification
    user = UserStub.new(false, false)
    project = Object.new

    policy = ProjectPolicy.new(user, project)

    refute policy.confirm_recertification?
    refute policy.request_recertification?
  end
end
