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
#  suspicious         :boolean          default(FALSE), not null
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
#  index_votes_on_suspicious_and_created_at  (suspicious,created_at)
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
  SUSPICIOUS_VOTE_THRESHOLD = 30

  CATEGORIES = {
    originality: "How distinct it is from common projects?",
    technical: "How much effort did the baker put into the implementation?",
    usability: "Did you like using it? Could you use it at all?",
    storytelling: "How well does the baker document the development journey through devlogs, documentation, and READMEs?"
  }.freeze

  SCORE_COLUMNS_BY_CATEGORY = {
    originality: :originality_score,
    technical: :technical_score,
    usability: :usability_score,
    storytelling: :storytelling_score
  }.freeze

  def self.enabled_categories = CATEGORIES.keys
  def self.score_columns = SCORE_COLUMNS_BY_CATEGORY.values
  def self.score_column_for!(category) = SCORE_COLUMNS_BY_CATEGORY.fetch(category.to_sym)

  scope :legitimate, -> { where(suspicious: false) }
  scope :suspicious, -> { where(suspicious: true) }

  before_save :mark_suspicious_if_fast

  belongs_to :user, counter_cache: true
  belongs_to :project
  belongs_to :ship_event, class_name: "Post::ShipEvent", counter_cache: true

  has_paper_trail on: [ :create, :update, :destroy ]

  after_commit :refresh_majority_judgment_scores, on: [ :create, :destroy ]
  after_commit :trigger_payout_calculation, on: [ :create, :destroy ]
  after_commit :increment_user_vote_balance, on: :create

  validates(*score_columns, inclusion: { in: 1..6, message: "must be between 1 and 6" }, allow_nil: true)
  validate :all_categories_scored
  validate :user_cannot_vote_on_own_projects
  validate :ship_event_matches_project

  def category_description(category) = CATEGORIES[category.to_sym]

  private

  def all_categories_scored
    missing = self.class.score_columns.select { |col| self[col].blank? }
    errors.add(:base, "All categories must be scored") if missing.any?
  end

  def user_cannot_vote_on_own_projects
    errors.add(:user, "cannot vote on own projects") if project&.users&.exists?(user_id)
  end

  def refresh_majority_judgment_scores
    ShipEventMajorityJudgmentRefreshJob.perform_later
  end

  def trigger_payout_calculation
    ShipEventPayoutCalculatorJob.perform_later
  end

  def increment_user_vote_balance
    user.increment!(:vote_balance, 1)
  end

  def ship_event_matches_project
    return if ship_event.blank? || project_id.blank?

    expected_project_id = ship_event.post&.project_id
    return if expected_project_id.blank?

    errors.add(:project, "does not match ship event") if project_id != expected_project_id
  end

  def mark_suspicious_if_fast
    return if time_taken_to_vote.nil?

    self.suspicious = time_taken_to_vote < SUSPICIOUS_VOTE_THRESHOLD
  end
end
