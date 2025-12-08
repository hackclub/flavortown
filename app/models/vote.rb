# == Schema Information
#
# Table name: votes
#
#  id                 :bigint           not null, primary key
#  category           :integer          default("originality"), not null
#  demo_url_clicked   :boolean
#  reason             :text
#  repo_url_clicked   :boolean
#  score              :integer          not null
#  time_taken_to_vote :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  project_id         :bigint           not null
#  ship_event_id      :bigint
#  user_id            :bigint           not null
#
# Indexes
#
#  index_votes_on_project_id                           (project_id)
#  index_votes_on_ship_event_id                        (ship_event_id)
#  index_votes_on_user_id                              (user_id)
#  index_votes_on_user_id_and_project_id_and_category  (user_id,project_id,category) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (ship_event_id => post_ship_events.id)
#  fk_rails_...  (user_id => users.id)
#
class Vote < ApplicationRecord
  belongs_to :user
  belongs_to :project
  belongs_to :ship_event, class_name: "Post::ShipEvent", optional: true, counter_cache: true

  validate :score_must_be_in_range
  validate :user_cannot_vote_on_own_projects

  before_validation :set_ship_event, on: :create

  class Category
    attr_reader :id, :name, :description

    def initialize(id:, name:, description:)
      @id = id
      @name = name
      @description = description
    end

    ALL = [
      new(id: 0, name: :originality, description: "How distinct it is from common projects?"),
      new(id: 1, name: :technical, description: "How much effort did the baker put into the implementation?"),
      new(id: 2, name: :usability, description: "Did you like using it? Could you use it at all?")
    ].freeze

    def self.all
      ALL
    end

    def self.to_h
      ALL.index_by(&:name).transform_values(&:id)
    end
  end

  enum :category, Category.to_h, prefix: true

  def category_details
    Category.all.find { |c| c.name == category.to_sym }
  end

  private

  def set_ship_event
    return if ship_event_id.present?

    self.ship_event = project&.posts
                             &.where(postable_type: "Post::ShipEvent")
                             &.order(created_at: :desc)
                             &.first
                             &.postable
  end

  def score_must_be_in_range
    unless (1..5).include?(score)
      errors.add(:base, "You need to also vote on #{category}")
    end
  end

  def user_cannot_vote_on_own_projects
    errors.add(:user, "cannot vote on own projects") if project.users.exists?(user_id)
  end
end
