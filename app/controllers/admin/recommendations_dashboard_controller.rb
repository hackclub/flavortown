# frozen_string_literal: true

module Admin
  class RecommendationsDashboardController < ApplicationController
    def index
      authorize :admin, :access_recommendations_dashboard?

      # General stats
      @total_recommendations = DiscoRecommendation.count
      @total_users_with_recs = DiscoRecommendation.where(subject_type: "User").distinct.count(:subject_id)
      @total_projects_with_recs = DiscoRecommendation.where(subject_type: "Project").distinct.count(:subject_id)

      # Average scores
      @avg_user_score = DiscoRecommendation.where(subject_type: "User").average(:score) || 0
      @avg_project_score = DiscoRecommendation.where(subject_type: "Project").average(:score) || 0

      # Context breakdown
      @context_breakdown = DiscoRecommendation.group(:context).count

      # Recent generations (last 24 hours)
      @recent_recommendations = DiscoRecommendation.where("created_at > ?", 24.hours.ago).count

      # Top recommended projects (most recommended across all users)
      @top_recommended_projects = DiscoRecommendation
        .where(item_type: "Project")
        .group(:item_id)
        .select("item_id, COUNT(*) as rec_count, AVG(score) as avg_score")
        .order("rec_count DESC")
        .limit(10)
        .map do |rec|
          project = Project.find_by(id: rec.item_id)
          next unless project
          [ project, rec.rec_count, rec.avg_score.to_f ]
        end.compact

      # Top users by recommendation count
      @top_users_with_recs = DiscoRecommendation
        .where(subject_type: "User")
        .group(:subject_id)
        .select("subject_id, COUNT(*) as rec_count, AVG(score) as avg_score")
        .order("rec_count DESC")
        .limit(10)
        .map do |rec|
          user = User.find_by(id: rec.subject_id)
          next unless user
          [ user, rec.rec_count, rec.avg_score.to_f ]
        end.compact

      # Top projects with recommendations (projects that recommend others)
      @top_projects_with_recs = DiscoRecommendation
        .where(subject_type: "Project")
        .group(:subject_id)
        .select("subject_id, COUNT(*) as rec_count, AVG(score) as avg_score")
        .order("rec_count DESC")
        .limit(10)
        .map do |rec|
          project = Project.find_by(id: rec.subject_id)
          next unless project
          [ project, rec.rec_count, rec.avg_score.to_f ]
        end.compact

      # Score distribution
      @score_distribution = {
        "0.0 - 0.2" => DiscoRecommendation.where("score >= 0.0 AND score < 0.2").count,
        "0.2 - 0.4" => DiscoRecommendation.where("score >= 0.2 AND score < 0.4").count,
        "0.4 - 0.6" => DiscoRecommendation.where("score >= 0.4 AND score < 0.6").count,
        "0.6 - 0.8" => DiscoRecommendation.where("score >= 0.6 AND score < 0.8").count,
        "0.8 - 1.0" => DiscoRecommendation.where("score >= 0.8").count
      }

      # Recent recommendations list
      @recent_list = DiscoRecommendation
        .includes(:subject, :item)
        .order(created_at: :desc)
        .limit(50)

      # Feature flag status
      @flipper_flags = {
        user_recommendations: Flipper.enabled?(:user_recommendations),
        project_recommendations: Flipper.enabled?(:project_recommendations),
        refresh_recommendations: Flipper.enabled?(:refresh_recommendations),
        recommendation_scores: Flipper.enabled?(:recommendation_scores)
      }
    end

    def refresh_all
      authorize :admin, :access_recommendations_dashboard?

      ProjectRecommendationsJob.perform_later

      redirect_to admin_recommendations_dashboard_path, notice: "Recommendation refresh job queued. Check back in a few minutes."
    end

    def clear_cache
      authorize :admin, :access_recommendations_dashboard?

      # Clear all recommendation caches
      Rails.cache.delete_matched("user/*/recommendations")
      Rails.cache.delete_matched("project/*/recommendations")

      redirect_to admin_recommendations_dashboard_path, notice: "Recommendation caches cleared."
    end
  end
end
