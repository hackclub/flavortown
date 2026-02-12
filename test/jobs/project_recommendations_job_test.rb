# frozen_string_literal: true

require "test_helper"

class ProjectRecommendationsJobTest < ActiveJob::TestCase
  test "job calls RecommendationService" do
    RecommendationService.expects(:generate_all_recommendations).once

    ProjectRecommendationsJob.perform_now
  end

  test "job is queued in literally_whenever queue" do
    assert_equal :literally_whenever, ProjectRecommendationsJob.new.queue_name
  end
end
