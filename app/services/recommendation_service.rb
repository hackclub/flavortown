# frozen_string_literal: true

class RecommendationService
  WEIGHTS = {
    vote: 5.0,
    like: 3.0,
    view: 1.0,
    follow: 4.0
  }.freeze

  TIME_DECAY_DAYS = 30
  MIN_INTERACTIONS_FOR_COLLABORATIVE = 5
  MIN_CONFIDENCE_SCORE = 0.3
  MAX_RECOMMENDATIONS_PER_USER = 10
  MAX_RECOMMENDATIONS_PER_PROJECT = 8

  class << self
    def generate_all_recommendations
      Rails.logger.info "[RecommendationService] Starting full recommendation generation"

      data = build_interaction_matrix

      if data.size >= MIN_INTERACTIONS_FOR_COLLABORATIVE
        generate_collaborative_recommendations(data)
      else
        Rails.logger.info "[RecommendationService] Not enough data for collaborative filtering (#{data.size} interactions), using content-based only"
      end

      generate_content_based_fallbacks

      Rails.logger.info "[RecommendationService] Completed recommendation generation"
    end

    def generate_for_user(user)
      return [] unless user.is_a?(User)

      data = build_interaction_matrix
      recommender = train_recommender(data)

      return content_based_for_user(user) unless recommender

      recs = recommender.user_recs(user.id)
      apply_filters_and_save(user, recs, :user_based)
    end

    def generate_for_project(project)
      return [] unless project.is_a?(Project)

      data = build_interaction_matrix
      recommender = train_recommender(data)

      return content_based_for_project(project) unless recommender

      recs = recommender.item_recs(project.id)
      apply_filters_and_save(project, recs, :item_based)
    end

    private

    def build_interaction_matrix
      interactions = []

      # Add views with time decay
      add_view_interactions(interactions)

      # Add likes with time decay
      add_like_interactions(interactions)

      # Add votes with time decay
      add_vote_interactions(interactions)

      # Add follows with time decay
      add_follow_interactions(interactions)

      # Aggregate by user-item pair, summing weighted scores
      aggregate_interactions(interactions)
    end

    def add_view_interactions(interactions)
      Ahoy::Event.where(name: "Viewed project")
                 .where.not(user_id: nil)
                 .where("properties->>'project_id' IS NOT NULL")
                 .where("time > ?", TIME_DECAY_DAYS.days.ago)
                 .find_each do |event|
        project_id = event.properties["project_id"].to_i
        weight = calculate_time_decay(event.time) * WEIGHTS[:view]

        interactions << {
          user_id: event.user_id,
          item_id: project_id,
          weight: weight
        }
      end
    end

    def add_like_interactions(interactions)
      Like.where(likeable_type: "Post")
          .joins("INNER JOIN posts ON posts.id = likes.likeable_id")
          .where("likes.created_at > ?", TIME_DECAY_DAYS.days.ago)
          .find_each do |like|
        weight = calculate_time_decay(like.created_at) * WEIGHTS[:like]

        interactions << {
          user_id: like.user_id,
          item_id: like.post.project_id,
          weight: weight
        }
      end
    end

    def add_vote_interactions(interactions)
      Vote.where("created_at > ?", TIME_DECAY_DAYS.days.ago)
          .find_each do |vote|
        weight = calculate_time_decay(vote.created_at) * WEIGHTS[:vote]

        interactions << {
          user_id: vote.user_id,
          item_id: vote.project_id,
          weight: weight
        }
      end
    end

    def add_follow_interactions(interactions)
      ProjectFollow.where("created_at > ?", TIME_DECAY_DAYS.days.ago)
                   .find_each do |follow|
        weight = calculate_time_decay(follow.created_at) * WEIGHTS[:follow]

        interactions << {
          user_id: follow.user_id,
          item_id: follow.project_id,
          weight: weight
        }
      end
    end

    def calculate_time_decay(timestamp)
      return 1.0 if timestamp.nil?

      days_ago = (Time.current - timestamp) / 1.day
      decay_factor = Math.exp(-days_ago / TIME_DECAY_DAYS.to_f)
      [ decay_factor, 0.1 ].max
    end

    def aggregate_interactions(interactions)
      interactions.group_by { |i| [ i[:user_id], i[:item_id] ] }
                  .map do |(user_id, item_id), group|
        {
          user_id: user_id,
          item_id: item_id,
          value: group.sum { |i| i[:weight] }
        }
      end
    end

    def train_recommender(data)
      return nil if data.empty?

      recommender = Disco::Recommender.new
      recommender.fit(data)
      recommender.optimize_user_recs
      recommender.optimize_item_recs
      recommender
    end

    def generate_collaborative_recommendations(data)
      recommender = train_recommender(data)
      return unless recommender

      # Generate user-based recommendations
      User.find_each do |user|
        begin
          recs = recommender.user_recs(user.id)
          apply_filters_and_save(user, recs, :user_based)
        rescue => e
          Rails.logger.error "[RecommendationService] Error generating user recommendations for user #{user.id}: #{e.message}"
        end
      end

      # Generate item-based recommendations
      Project.find_each do |project|
        begin
          recs = recommender.item_recs(project.id)
          apply_filters_and_save(project, recs, :item_based)
        rescue => e
          Rails.logger.error "[RecommendationService] Error generating item recommendations for project #{project.id}: #{e.message}"
        end
      end
    end

    def apply_filters_and_save(subject, recommendations, context)
      return if recommendations.blank?

      # Filter by confidence threshold
      filtered = recommendations.select { |rec| rec[:score] >= MIN_CONFIDENCE_SCORE }

      # Filter out user's own projects if subject is a User
      if subject.is_a?(User)
        owned_project_ids = subject.projects.pluck(:id)
        filtered = filtered.reject { |rec| owned_project_ids.include?(rec[:item_id]) }
      end

      # Filter shadow-banned or deleted projects
      valid_project_ids = Project.where(id: filtered.map { |r| r[:item_id] })
                                 .excluding_shadow_banned
                                 .where(deleted_at: nil)
                                 .pluck(:id)
                                 .to_set

      filtered = filtered.select { |rec| valid_project_ids.include?(rec[:item_id]) }

      # Limit recommendations
      limit = subject.is_a?(User) ? MAX_RECOMMENDATIONS_PER_USER : MAX_RECOMMENDATIONS_PER_PROJECT
      filtered = filtered.first(limit)

      # Save recommendations
      save_recommendations(subject, filtered, context)
    end

    def save_recommendations(subject, recommendations, context)
      return if recommendations.blank?

      context_string = context.to_s

      # Clear existing recommendations for this context
      DiscoRecommendation.where(subject: subject, context: context_string).destroy_all

      # Insert new recommendations
      now = Time.current
      records = recommendations.map do |rec|
        {
          subject_type: subject.class.name,
          subject_id: subject.id,
          item_type: "Project",
          item_id: rec[:item_id],
          context: context_string,
          score: rec[:score],
          created_at: now,
          updated_at: now
        }
      end

      DiscoRecommendation.insert_all!(records) if records.any?
    end

    def generate_content_based_fallbacks
      # Generate content-based recommendations for users with sparse interaction data
      User.find_each do |user|
        next if has_enough_interactions?(user)

        recs = content_based_for_user(user)
        save_recommendations(user, recs, :content_based) if recs.any?
      end

      # Generate content-based recommendations for all projects as fallback
      Project.find_each do |project|
        recs = content_based_for_project(project)
        save_recommendations(project, recs, :content_based) if recs.any?
      end
    end

    def has_enough_interactions?(user)
      interaction_count = Ahoy::Event.where(user_id: user.id, name: "Viewed project").count +
                         Like.where(user_id: user.id).count +
                         Vote.where(user_id: user.id).count +
                         ProjectFollow.where(user_id: user.id).count

      interaction_count >= MIN_INTERACTIONS_FOR_COLLABORATIVE
    end

    def content_based_for_user(user)
      # Get user's preferred categories and types from their interactions
      liked_project_ids = Like.where(user_id: user.id, likeable_type: "Post")
                              .joins("INNER JOIN posts ON posts.id = likes.likeable_id")
                              .pluck("posts.project_id")

      voted_project_ids = Vote.where(user_id: user.id).pluck(:project_id)
      followed_project_ids = ProjectFollow.where(user_id: user.id).pluck(:project_id)

      interacted_project_ids = (liked_project_ids + voted_project_ids + followed_project_ids).uniq

      return [] if interacted_project_ids.empty?

      # Get categories and types the user likes
      interacted_projects = Project.where(id: interacted_project_ids)
      preferred_categories = interacted_projects.flat_map(&:project_categories).compact.uniq
      preferred_types = interacted_projects.map(&:project_type).compact.uniq

      return [] if preferred_categories.empty? && preferred_types.empty?

      # Find similar projects
      candidate_projects = Project.excluding_shadow_banned
                                  .where(deleted_at: nil)
                                  .where.not(id: user.projects.pluck(:id) + interacted_project_ids)

      scored_projects = candidate_projects.map do |project|
        score = calculate_content_similarity(project, preferred_categories, preferred_types)
        { item_id: project.id, score: score } if score > 0
      end.compact

      scored_projects.sort_by { |p| -p[:score] }
                     .first(MAX_RECOMMENDATIONS_PER_USER)
    end

    def content_based_for_project(project)
      return [] if project.project_categories.blank? && project.project_type.blank?

      candidate_projects = Project.excluding_shadow_banned
                                  .where(deleted_at: nil)
                                  .where.not(id: project.id)

      scored_projects = candidate_projects.map do |other_project|
        score = calculate_project_similarity(project, other_project)
        { item_id: other_project.id, score: score } if score > 0
      end.compact

      scored_projects.sort_by { |p| -p[:score] }
                     .first(MAX_RECOMMENDATIONS_PER_PROJECT)
    end

    def calculate_content_similarity(project, preferred_categories, preferred_types)
      score = 0.0

      # Category overlap
      if project.project_categories.present? && preferred_categories.any?
        category_overlap = (project.project_categories & preferred_categories).size
        score += category_overlap * 0.3
      end

      # Type match
      if project.project_type.present? && preferred_types.include?(project.project_type)
        score += 0.5
      end

      # Bonus for projects with more engagement
      if project.duration_seconds.to_i > 3600 # More than 1 hour of dev time
        score += 0.1
      end

      [ score, 1.0 ].min
    end

    def calculate_project_similarity(project_a, project_b)
      score = 0.0

      # Category overlap (Jaccard similarity)
      if project_a.project_categories.present? && project_b.project_categories.present?
        categories_a = project_a.project_categories.to_set
        categories_b = project_b.project_categories.to_set
        intersection = (categories_a & categories_b).size
        union = (categories_a | categories_b).size

        if union > 0
          score += (intersection.to_f / union) * 0.6
        end
      end

      # Type match
      if project_a.project_type.present? && project_a.project_type == project_b.project_type
        score += 0.3
      end

      # Similar development time (within 50% of each other)
      if project_a.duration_seconds.to_i > 0 && project_b.duration_seconds.to_i > 0
        time_ratio = [ project_a.duration_seconds, project_b.duration_seconds ].min.to_f /
                     [ project_a.duration_seconds, project_b.duration_seconds ].max
        score += time_ratio * 0.1 if time_ratio > 0.5
      end

      [ score, 1.0 ].min
    end
  end
end
