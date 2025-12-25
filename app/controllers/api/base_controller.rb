class Api::BaseController < ApplicationController
  after_action :set_performance_headers

  private

  def set_performance_headers
    response.set_header("X-DB-Queries", QueryCount::Counter.counter.to_s)
    response.set_header("X-DB-Cached", QueryCount::Counter.counter_cache.to_s)
    response.set_header("X-Cache-Hits", (Thread.current[:cache_hits] || 0).to_s)
    response.set_header("X-Cache-Misses", (Thread.current[:cache_misses] || 0).to_s)
  end
end
