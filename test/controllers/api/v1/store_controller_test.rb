require "test_helper"

class Api::V1::StoreControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @auth_headers = { "Authorization" => "Bearer #{@user.api_key}" }
  end

  test "index returns JSON" do
    get api_v1_store_index_url, headers: @auth_headers
    assert_response :success
    assert_nothing_raised { JSON.parse(response.body) }
  end
end
