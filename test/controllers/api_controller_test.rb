require "test_helper"

class ApiControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get api_index_url
    assert_response :success
  end
end
