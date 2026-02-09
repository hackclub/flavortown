# frozen_string_literal: true

class DiscoRecommendation < ApplicationRecord
  belongs_to :subject, polymorphic: true
  belongs_to :item, polymorphic: true

  validates :subject_type, presence: true
  validates :subject_id, presence: true
  validates :item_type, presence: true
  validates :item_id, presence: true
  validates :score, presence: true, numericality: true

  scope :for_users, -> { where(subject_type: "User") }
  scope :for_projects, -> { where(subject_type: "Project") }
  scope :by_context, ->(context) { where(context: context) }
  scope :high_score, -> { where("score >= ?", 0.5) }
  scope :recent, -> { where("created_at > ?", 24.hours.ago) }
end
