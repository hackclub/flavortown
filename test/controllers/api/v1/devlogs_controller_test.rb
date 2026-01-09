require "test_helper"

class Api::V1::DevlogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @auth_headers = { "Authorization" => "Bearer #{@user.api_key}" }
    @devlog = post_devlogs(:one)
  end

  test "index returns JSON" do
    get api_v1_devlogs_url, headers: @auth_headers
    assert_response :success
    assert_nothing_raised { JSON.parse(response.body) }
  end

  test "show returns JSON" do
    get api_v1_devlog_url(@devlog), headers: @auth_headers
    assert_response :success
    assert_nothing_raised { JSON.parse(response.body) }
  end

  test "show returns 404 for non-existent devlog" do
    get api_v1_devlog_url(id: 999999999), headers: @auth_headers
    assert_response :not_found
  end
end
