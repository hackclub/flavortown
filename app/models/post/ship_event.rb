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
end
