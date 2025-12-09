# == Schema Information
#
# Table name: post_ship_events
#
#  id          :bigint           not null, primary key
#  body        :string
#  hours       :float
#  multiplier  :float
#  payout      :float
#  votes_count :integer          default(0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Post::ShipEvent < ApplicationRecord
  include Postable
  include Ledgerable

  VOTES_REQUIRED_FOR_PAYOUT = 20

  has_many :votes, foreign_key: :ship_event_id, dependent: :nullify, inverse_of: :ship_event

  validates :body, presence: { message: "Update message can't be blank" }
end
