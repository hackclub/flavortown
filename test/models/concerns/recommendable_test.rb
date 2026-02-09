# frozen_string_literal: true

require "test_helper"

class RecommendableTest < ActiveSupport::TestCase
  test "user can access recommended_projects_with_details" do
    user = users(:one)

    # Create a recommendation
    project = projects(:two)
    DiscoRecommendation.create!(
      subject: user,
      item: project,
      context: "user_based",
      score: 0.8
    )

    result = user.recommended_projects_with_details

    assert_kind_of Array, result
    assert result.any? { |r| r[:project] == project }
  end

  test "project can access recommended_projects_with_details" do
    project = projects(:one)
    other_project = projects(:two)

    DiscoRecommendation.create!(
      subject: project,
      item: other_project,
      context: "item_based",
      score: 0.9
    )

    result = project.recommended_projects_with_details

    assert_kind_of Array, result
    assert result.any? { |r| r[:project] == other_project }
  end

  test "recommendation_explanation_for returns context-appropriate message" do
    user = users(:one)
    project = projects(:two)

    # Test user_based explanation
    DiscoRecommendation.create!(
      subject: user,
      item: project,
      context: "user_based",
      score: 0.8
    )

    explanation = user.recommendation_explanation_for(project)
    assert_equal "Users with similar interests viewed this project", explanation

    # Test item_based explanation
    DiscoRecommendation.where(subject: user, item: project).destroy_all
    DiscoRecommendation.create!(
      subject: user,
      item: project,
      context: "item_based",
      score: 0.8
    )

    explanation = user.recommendation_explanation_for(project)
    assert_equal "Similar to projects you've viewed", explanation
  end

  test "recommendation_explanation_for returns nil for non-existent recommendation" do
    user = users(:one)
    project = projects(:two)

    explanation = user.recommendation_explanation_for(project)
    assert_nil explanation
  end

  test "refresh_recommendations! clears cache and regenerates" do
    user = users(:one)

    RecommendationService.expects(:generate_for_user).with(user).once

    user.refresh_recommendations!
  end
end
