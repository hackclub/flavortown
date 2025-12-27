class ScrapbookPopulateDevlogJob < ApplicationJob
  queue_as :default

  def perform(devlog_id)
    ScrapbookService.populate_devlog_from_url(devlog_id)
  end
end
