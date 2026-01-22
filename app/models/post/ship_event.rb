# == Schema Information
#
# Table name: post_ship_events
#
#  id                      :bigint           not null, primary key
#  body                    :string
#  certification_status    :string           default("pending")
#  feedback_reason         :text
#  feedback_video_url      :string
#  hours                   :float
#  multiplier              :float
#  originality_median      :decimal(5, 2)
#  originality_percentile  :decimal(5, 2)
#  overall_percentile      :decimal(5, 2)
#  overall_score           :decimal(5, 2)
#  payout                  :float
#  storytelling_median     :decimal(5, 2)
#  storytelling_percentile :decimal(5, 2)
#  synced_at               :datetime
#  technical_median        :decimal(5, 2)
#  technical_percentile    :decimal(5, 2)
#  usability_median        :decimal(5, 2)
#  usability_percentile    :decimal(5, 2)
#  votes_count             :integer          default(0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
class Post::ShipEvent < ApplicationRecord
  include Postable
  include Ledgerable

  VOTES_REQUIRED_FOR_PAYOUT = 15

  has_one :project, through: :post
  has_many :project_memberships, through: :project, source: :memberships
  has_many :project_members, through: :project, source: :users

  has_many :votes, foreign_key: :ship_event_id, dependent: :nullify, inverse_of: :ship_event

  validates :body, presence: { message: "Update message can't be blank" }

  def status
    project = post&.project
    return nil unless project

    ShipCertService.get_status(project)
  end

  def majority_judgment
    MajorityJudgmentService.call(self)
  end

  def hours
    project = post&.project
    return 0 unless project && created_at

    seconds = project.posts.of_devlogs(join: true)
                     .where("posts.created_at <= ?", created_at)
                     .where(post_devlogs: { deleted_at: nil })
                     .sum("post_devlogs.duration_seconds")
    seconds.to_f / 3600
  end

  def payout_eligible?
    certification_status == "approved" &&
      payout.blank? &&
      votes_count.to_i >= VOTES_REQUIRED_FOR_PAYOUT
  end

  def payout_recipient
    post&.user
  end
end
