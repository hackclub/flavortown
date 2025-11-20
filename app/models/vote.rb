class Vote < ApplicationRecord
  belongs_to :user
  belongs_to :project

  validates :score, inclusion: { in: 1..5 }
  validate :user_cannot_vote_on_own_projects

  enum :category, {
    creativity: 0,
    technical: 1,
    usability: 2
  }, prefix: true

  private

  def user_cannot_vote_on_own_projects
    errors.add(:user, "cannot vote on own projects") if user_id == project.user.id
  end
end
