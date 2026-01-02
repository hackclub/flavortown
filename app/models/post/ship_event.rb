# == Schema Information
#
# Table name: post_ship_events
#
#  id                   :bigint           not null, primary key
#  body                 :string
#  certification_status :string           default("pending")
#  feedback_reason      :text
#  feedback_video_url   :string
#  hours                :float
#  multiplier           :float
#  payout               :float
#  synced_at            :datetime
#  votes_count          :integer          default(0), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
class Post::ShipEvent < ApplicationRecord
  include Postable
  include Ledgerable

  VOTES_REQUIRED_FOR_PAYOUT = 20

  has_many :votes, foreign_key: :ship_event_id, dependent: :nullify, inverse_of: :ship_event

  validates :body, presence: { message: "Update message can't be blank" }

  after_create :track_ship_event_funnel

  def status
    project = post&.project
    return nil unless project

    ShipCertService.get_status(project)
  end

  private

  def track_ship_event_funnel
    FunnelTrackerService.track(
      event_name: "ship_event_created",
      user: post.user,
      properties: { ship_event_id: id, project_id: post.project.id }
    )
  end
end
