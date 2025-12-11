# frozen_string_literal: true

# == Schema Information
#
# Table name: user_achievements
#
#  id               :bigint           not null, primary key
#  achievement_slug :string           not null
#  earned_at        :datetime         not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_user_achievements_on_user_id                       (user_id)
#  index_user_achievements_on_user_id_and_achievement_slug  (user_id,achievement_slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class User
  class Achievement < ApplicationRecord
    self.table_name = "user_achievements"

    belongs_to :user

    validates :achievement_slug, presence: true, inclusion: { in: ::Achievement.all_slugs.map(&:to_s) }
    validates :achievement_slug, uniqueness: { scope: :user_id }
    validates :earned_at, presence: true

    def achievement
      ::Achievement.find(achievement_slug)
    end
  end
end
