class SitemapsController < ApplicationController
  def index
    expires_in 1.hour, public: true
    render xml: Cache::SitemapJob.fetch
  end
end
