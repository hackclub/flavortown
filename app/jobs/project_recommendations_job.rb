class ProjectRecommendationsJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    RecommendationService.generate_all_recommendations
  end
end
