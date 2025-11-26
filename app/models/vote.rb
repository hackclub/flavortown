class Vote < ApplicationRecord
  belongs_to :user
  belongs_to :project

  validate :score_must_be_in_range
  validate :user_cannot_vote_on_own_projects

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

  def score_must_be_in_range
    unless (1..5).include?(score)
      errors.add(:base, "You need to also vote on #{category}")
    end
  end

  def user_cannot_vote_on_own_projects
    errors.add(:user, "cannot vote on own projects") if project.users.exists?(user_id)
  end
end
