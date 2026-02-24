# frozen_string_literal: true

# == Schema Information
#
# Table name: disco_recommendations
#
#  id           :bigint           not null, primary key
#  context      :string
#  item_type    :string
#  score        :float
#  subject_type :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  item_id      :bigint
#  subject_id   :bigint
#
# Indexes
#
#  index_disco_recommendations_on_item     (item_type,item_id)
#  index_disco_recommendations_on_subject  (subject_type,subject_id)
#
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
