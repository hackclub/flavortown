class Api::BaseController < ApplicationController
  after_action :set_performance_headers

  rescue_from StandardError, with: :handle_err
  rescue_from ActiveRecord::RecordNotFound, with: :handle_404
  rescue_from ActiveRecord::RecordInvalid, with: :handle_bad

  private

  def handle_err(exception)
    # this will help with debugging
    Sentry.capture_exception(
      exception,
      extra: {
        request_id: request.request_id,
        user_id: respond_to?(:current_api_user) ? current_api_user&.id : nil,
        endpoint: "#{request.method} #{request.path}",
        params: request.filtered_parameters,
        action: action_name
      },
      tags: {
        controller: controller_name,
        action: action_name
      }
    )

    render json: { error: "An unexpected error occurred" }, status: :internal_server_error
  end

  def handle_404
    render json: { error: "Resource not found" }, status: :not_found
  end

  def handle_bad(exception)
    render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_entity
  end

  def set_performance_headers
    response.set_header("X-DB-Queries", QueryCount::Counter.counter.to_s)
    response.set_header("X-DB-Cached", QueryCount::Counter.counter_cache.to_s)
    response.set_header("X-Cache-Hits", (Thread.current[:cache_hits] || 0).to_s)
    response.set_header("X-Cache-Misses", (Thread.current[:cache_misses] || 0).to_s)
  end
end
