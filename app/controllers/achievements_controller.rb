# frozen_string_literal: true

class AchievementsController < ApplicationController
  include Achievementable

  def index
    preloader = Achievement::Preloader.new(current_user)
    user_achievements_by_slug = current_user.achievements.index_by(&:achievement_slug)

    @achievements = Achievement.all.map do |achievement|
      user_achievement = user_achievements_by_slug[achievement.slug.to_s]
      earned = user_achievement.present? || preloader.earned?(achievement.slug)

      grant_achievement!(achievement.slug) if earned && user_achievement.nil?

      {
        achievement: achievement,
        earned: earned,
        earned_at: user_achievement&.earned_at,
        progress: earned ? nil : preloader.progress_for(achievement.slug)
      }
    end

    earned_slugs = @achievements.select { |a| a[:earned] }.map { |a| a[:achievement].slug }
    countable = Achievement.countable.select { |a| a.shown_to?(current_user, earned: earned_slugs.include?(a.slug)) }
    earned_countable = countable.count { |a| earned_slugs.include?(a.slug) }

    @achievement_stats = {
      earned: earned_countable,
      total: countable.count
    }
  end
end
