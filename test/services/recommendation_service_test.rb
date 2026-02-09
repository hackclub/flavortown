# frozen_string_literal: true

require "test_helper"

class RecommendationServiceTest < ActiveSupport::TestCase
  test "build_interaction_matrix aggregates multiple signals" do
    user = users(:one)
    project = projects(:one)

    # Create some test data
    Ahoy::Event.create!(
      name: "Viewed project",
      user_id: user.id,
      time: Time.current,
      properties: { "project_id" => project.id.to_s }
    )

    # The service should build interactions from data
    data = RecommendationService.send(:build_interaction_matrix)

    assert_kind_of Array, data
    # Should have at least one interaction
    assert data.any? { |i| i[:user_id] == user.id && i[:item_id] == project.id }
  end

  test "calculate_time_decay reduces weight for older interactions" do
    recent = RecommendationService.send(:calculate_time_decay, 1.day.ago)
    old = RecommendationService.send(:calculate_time_decay, 29.days.ago)
    very_old = RecommendationService.send(:calculate_time_decay, 31.days.ago)

    assert recent > old, "Recent interactions should have higher weight"
    assert_equal 0.1, very_old, "Very old interactions should have minimum weight"
  end

  test "content_based_for_user returns empty array for users with no interactions" do
    user = users(:one)
    # Ensure user has no interactions
    Like.where(user_id: user.id).destroy_all
    Vote.where(user_id: user.id).destroy_all
    ProjectFollow.where(user_id: user.id).destroy_all
    Ahoy::Event.where(user_id: user.id, name: "Viewed project").destroy_all

    result = RecommendationService.send(:content_based_for_user, user)
    assert_equal [], result
  end

  test "calculate_content_similarity returns higher scores for matching categories" do
    preferred_categories = [ "Web App", "CLI" ]
    preferred_types = [ "web" ]

    project_with_match = Project.new(
      project_categories: [ "Web App" ],
      project_type: "web",
      duration_seconds: 7200
    )

    project_without_match = Project.new(
      project_categories: [ "Hardware" ],
      project_type: "hardware",
      duration_seconds: 7200
    )

    score_with_match = RecommendationService.send(:calculate_content_similarity, project_with_match, preferred_categories, preferred_types)
    score_without_match = RecommendationService.send(:calculate_content_similarity, project_without_match, preferred_categories, preferred_types)

    assert score_with_match > score_without_match
  end

  test "calculate_project_similarity measures category overlap" do
    project_a = Project.new(
      project_categories: [ "Web App", "CLI" ],
      project_type: "web",
      duration_seconds: 3600
    )

    project_b = Project.new(
      project_categories: [ "Web App", "Extension" ],
      project_type: "web",
      duration_seconds: 4000
    )

    project_c = Project.new(
      project_categories: [ "Hardware" ],
      project_type: "hardware",
      duration_seconds: 3600
    )

    score_ab = RecommendationService.send(:calculate_project_similarity, project_a, project_b)
    score_ac = RecommendationService.send(:calculate_project_similarity, project_a, project_c)

    assert score_ab > score_ac, "Projects with similar categories should have higher similarity"
  end
end
