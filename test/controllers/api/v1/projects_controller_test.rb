require "test_helper"

class Api::V1::ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
    @user = users(:one)
    @auth_headers = { "Authorization" => "Bearer #{@user.api_key}" }
  end

  test "index returns success and includes devlog_ids" do
    get api_v1_projects_url, headers: @auth_headers
    assert_response :success, "Expected success but got: #{response.body[0..500]}"

    json = JSON.parse(response.body)
    assert json.key?("projects"), "Response should include projects key"
    assert json["projects"].first.key?("devlog_ids"), "Each project should include devlog_ids"
  end

  test "show returns success and includes devlog_ids" do
    get api_v1_project_url(@project), headers: @auth_headers
    assert_response :success, "Expected success but got: #{response.body}"

    json = JSON.parse(response.body)
    assert json.key?("devlog_ids"), "Response should include devlog_ids. Got: #{json.inspect}"
    assert_kind_of Array, json["devlog_ids"]
  end

  test "show returns 404 for non-existent project" do
    get api_v1_project_url(id: 999999999), headers: @auth_headers
    assert_response :not_found
  end
end
