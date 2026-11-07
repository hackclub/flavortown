require "test_helper"

class PruneActiveInsightsJobTest < ActiveJob::TestCase
  test "deletes insights older than the retention window and keeps recent ones" do
    old_request = ActiveInsights::Request.create!(started_at: 31.days.ago, finished_at: 31.days.ago, controller: "ProjectsController", action: "show")
    new_request = ActiveInsights::Request.create!(started_at: 1.day.ago, finished_at: 1.day.ago, controller: "ProjectsController", action: "show")
    old_job = ActiveInsights::Job.create!(started_at: 31.days.ago, finished_at: 31.days.ago, job: "SomeJob")
    new_job = ActiveInsights::Job.create!(started_at: 1.day.ago, finished_at: 1.day.ago, job: "SomeJob")

    PruneActiveInsightsJob.perform_now

    assert_not ActiveInsights::Request.exists?(old_request.id)
    assert ActiveInsights::Request.exists?(new_request.id)
    assert_not ActiveInsights::Job.exists?(old_job.id)
    assert ActiveInsights::Job.exists?(new_job.id)
  end
end
