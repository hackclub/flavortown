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

  VOTES_REQUIRED_FOR_PAYOUT = 12

  has_one :project, through: :post
  has_many :project_memberships, through: :project, source: :memberships
  has_many :project_members, through: :project, source: :users

  has_many :votes, foreign_key: :ship_event_id, dependent: :nullify, inverse_of: :ship_event

  after_commit :decrement_user_vote_balance, on: :create

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

    ship_event_post = post
    previous_ship_event_post = project.posts.of_ship_events
                                      .where("posts.created_at < ?", ship_event_post.created_at)
                                      .order("posts.created_at DESC")
                                      .first

    # created_at if first otherwise use the last ship_event
    start_time = previous_ship_event_post ? previous_ship_event_post.created_at : project.created_at

    seconds = project.posts.of_devlogs(join: true)
                     .where("posts.created_at >= ? AND posts.created_at <= ?", start_time, ship_event_post.created_at)
                     .where(post_devlogs: { deleted_at: nil })
                     .sum("post_devlogs.duration_seconds")
    seconds.to_f / 3600
  end

  def payout_eligible?
    return false unless certification_status == "approved"
    return false unless payout.blank?
    return false unless votes_count.to_i >= VOTES_REQUIRED_FOR_PAYOUT

    payout_user = payout_recipient
    return false unless payout_user
    return false if payout_user.vote_balance < 0

    true
  end

  def payout_recipient
    post&.user
  end

  private

  def decrement_user_vote_balance
    return unless post&.user

    post.user.increment!(:vote_balance, -15)
  end
end
