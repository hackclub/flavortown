require "test_helper"

class Api::V1::ProjectDevlogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @auth_headers = { "Authorization" => "Bearer #{@user.api_key}" }
    @project = projects(:one)
  end

  test "index returns JSON" do
    get api_v1_project_devlogs_url(@project), headers: @auth_headers
    assert_response :success
    assert_nothing_raised { JSON.parse(response.body) }
  end
end
