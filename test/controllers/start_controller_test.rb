require "test_helper"

class StartControllerTest < ActionDispatch::IntegrationTest
  setup do
    @verified_user = users(:verified_user)
    @ineligible_user = users(:ineligible_user)
  end

  test "redirects verified users to projects_path" do
    sign_in(@verified_user)
    get start_path
    assert_redirected_to projects_path
  end

  test "redirects ineligible users to kitchen_path" do
    sign_in(@ineligible_user)
    get start_path
    assert_redirected_to kitchen_path
  end

  test "allows unauthenticated users to access /start" do
    get start_path
    assert_response :success
  end
end
