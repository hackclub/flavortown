# frozen_string_literal: true

class AchievementsController < ApplicationController
  def index
    current_user.check_and_award_achievements!

    @achievements = Achievement.all.map do |achievement|
      user_achievement = current_user.achievements.find_by(achievement_slug: achievement.slug.to_s)
      {
        achievement: achievement,
        earned: user_achievement.present?,
        earned_at: user_achievement&.earned_at,
        progress: achievement.progress_for(current_user)
      }
    end
  end
end
