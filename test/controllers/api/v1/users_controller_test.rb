require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @auth_headers = { "Authorization" => "Bearer #{@user.api_key}" }
  end

  test "index returns JSON" do
    get api_v1_users_url, headers: @auth_headers
    assert_response :success
    assert_nothing_raised { JSON.parse(response.body) }
  end

  test "show returns JSON" do
    get api_v1_user_url(@user), headers: @auth_headers
    assert_response :success
    assert_nothing_raised { JSON.parse(response.body) }
  end

  test "show me returns current user" do
    get api_v1_user_url("me"), headers: @auth_headers
    assert_response :success
    assert_nothing_raised { JSON.parse(response.body) }
  end

  test "show returns 404 for non-existent user" do
    get api_v1_user_url(id: 999999999), headers: @auth_headers
    assert_response :not_found
  end
end
