# frozen_string_literal: true

module Achievementable
  extend ActiveSupport::Concern

  included do
    class_attribute :achievements_to_check, default: []
  end

  class_methods do
    def grant_earned_achievements(*slugs, **options)
      self.achievements_to_check += slugs.map(&:to_sym)
      after_action :check_and_grant_earned_achievements, **options
    end
  end

  private

  def grant_achievement!(slug, flash: :now)
    return nil unless current_user

    achievement = current_user.award_achievement!(slug)
    flash_achievement!(achievement, flash:) if achievement
    achievement
  end

  def check_and_grant_earned_achievements
    return unless current_user

    achievements_to_check.each do |slug|
      grant_achievement!(slug, flash: :later)
    end
  end

  def flash_achievement!(achievement, flash: :now)
    target = flash == :now ? self.flash.now : self.flash
    target[:achievements] ||= []
    target[:achievements] << {
      "slug" => achievement.slug.to_s,
      "name" => achievement.name,
      "description" => achievement.description,
      "icon" => achievement.icon,
      "cookie_reward" => achievement.cookie_reward
    }
  end
end
