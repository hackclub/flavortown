class DebugController < ApplicationController
  def error
    raise "Test error"
  end
end
