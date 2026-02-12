# frozen_string_literal: true

module Recommendable
  extend ActiveSupport::Concern

  included do
    def recommended_projects_with_details(limit: nil)
      cache_key = "#{self.class.name.downcase}/#{id}/recommendations"

      Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        recs = DiscoRecommendation.where(subject: self)
                                 .where(item_type: "Project")
                                 .order(score: :desc)
                                 .limit(limit)
                                 .includes(:item)

        recs.map do |rec|
          {
            project: rec.item,
            score: rec.score,
            context: rec.context
          }
        end
      end
    end

    def refresh_recommendations!
      if is_a?(User)
        RecommendationService.generate_for_user(self)
      elsif is_a?(Project)
        RecommendationService.generate_for_project(self)
      end

      # Clear cache
      Rails.cache.delete("#{self.class.name.downcase}/#{id}/recommendations")
    end

    def recommendation_explanation_for(project)
      rec = DiscoRecommendation.find_by(
        subject: self,
        item: project,
        item_type: "Project"
      )

      return nil unless rec

      case rec.context
      when "user_based"
        "Users with similar interests viewed this project"
      when "item_based"
        "Similar to projects you've viewed"
      when "content_based"
        "Matches your interests in #{project.project_categories&.join(', ')}"
      else
        "Recommended for you"
      end
    end
  end

  class_methods do
    def warm_recommendation_cache
      find_each do |record|
        record.recommended_projects_with_details
      end
    end
  end
end
