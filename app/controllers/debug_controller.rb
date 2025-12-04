class DebugController < ApplicationController
  def error
    begin
      raise "Test error for Sentry2"
    rescue => e
      Sentry.capture_exception(e)
      raise
    end
  end
end
