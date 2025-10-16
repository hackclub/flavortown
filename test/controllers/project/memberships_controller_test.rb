require "test_helper"

class Project::MembershipsControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get project_memberships_create_url
    assert_response :success
  end

  test "should get destroy" do
    get project_memberships_destroy_url
    assert_response :success
  end
end
