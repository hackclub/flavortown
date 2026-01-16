# == Schema Information
#
# Table name: votes
#
#  id                 :bigint           not null, primary key
#  demo_url_clicked   :boolean          default(FALSE)
#  originality_score  :integer
#  reason             :text
#  repo_url_clicked   :boolean          default(FALSE)
#  storytelling_score :integer
#  technical_score    :integer
#  time_taken_to_vote :integer
#  usability_score    :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  project_id         :bigint           not null
#  ship_event_id      :bigint           not null
#  user_id            :bigint           not null
#
# Indexes
#
#  index_votes_on_project_id                 (project_id)
#  index_votes_on_ship_event_id              (ship_event_id)
#  index_votes_on_user_id                    (user_id)
#  index_votes_on_user_id_and_ship_event_id  (user_id,ship_event_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (ship_event_id => post_ship_events.id)
#  fk_rails_...  (user_id => users.id)
#
class Vote < ApplicationRecord
  CATEGORIES = {
    originality: "How distinct it is from common projects?",
    technical: "How much effort did the baker put into the implementation?",
    usability: "Did you like using it? Could you use it at all?",
    storytelling: "How well does the baker document the development journey through devlogs, documentation, and READMEs?"
  }.freeze

  def self.enabled_categories = CATEGORIES.keys
  def self.score_columns = enabled_categories.map { |c| :"#{c}_score" }

  belongs_to :user, counter_cache: true
  belongs_to :project
  belongs_to :ship_event, class_name: "Post::ShipEvent", counter_cache: true

  validates(*score_columns, inclusion: { in: 1..6, message: "must be between 1 and 6" }, allow_nil: true)
  validate :all_categories_scored
  validate :user_cannot_vote_on_own_projects

  def category_description(category) = CATEGORIES[category.to_sym]

  private

  def all_categories_scored
    missing = self.class.score_columns.select { |col| self[col].blank? }
    errors.add(:base, "All categories must be scored") if missing.any?
  end

  def user_cannot_vote_on_own_projects
    errors.add(:user, "cannot vote on own projects") if project&.users&.exists?(user_id)
  end
end
