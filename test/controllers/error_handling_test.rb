require "test_helper"

class ErrorHandlingTest < Minitest::Test
  def setup
    @request = ActionDispatch::TestRequest.create
    @request.set_header("HTTP_ACCEPT", "application/json")
    @request.request_id = "error-test-request"
    @log = StringIO.new
    @original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(@log)
  end

  def teardown
    Rails.logger = @original_logger
  end

  def test_application_error_uses_request_id_and_logs_exception
    controller = build_controller(ApplicationController)
    controller.define_singleton_method(:current_user) { nil }

    controller.send(:handle_error, RuntimeError.new("Application failure"))

    assert_equal 500, controller.response.status
    assert_equal({ "error" => "Internal server error", "trace_id" => "error-test-request" }, JSON.parse(controller.response.body))
    assert_includes @log.string, "error-test-request"
    assert_includes @log.string, "Application failure"
  end

  def test_api_error_logs_exception_and_returns_generic_response
    controller = build_controller(Api::BaseController)

    controller.send(:handle_err, RuntimeError.new("Private API failure"))

    assert_equal 500, controller.response.status
    assert_equal({ "error" => "An unexpected error occurred" }, JSON.parse(controller.response.body))
    assert_includes @log.string, "error-test-request"
    assert_includes @log.string, "Private API failure"
  end

  def test_html_error_renders_with_request_reference
    @request.set_header("HTTP_ACCEPT", "text/html")
    @request.set_header("rack.session", ActionController::TestSession.new)
    controller = build_controller(ApplicationController)
    controller.define_singleton_method(:current_user) { nil }
    controller.instance_variable_set(:@hide_footer, true)

    controller.send(:handle_error, RuntimeError.new("Private application failure"))

    assert_equal 500, controller.response.status
    assert_includes controller.response.body, "error-test-request"
    refute_includes controller.response.body, "Private application failure"
  end

  private

  def build_controller(controller_class)
    controller = controller_class.new
    controller.set_request!(@request)
    controller.set_response!(ActionDispatch::TestResponse.new)
    controller
  end
end
