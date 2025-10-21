# == Schema Information
#
# Table name: post_ship_events
#
#  id         :bigint           not null, primary key
#  body       :string
#  hours      :float
#  multiplier :float
#  payout     :float
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Post::ShipEvent < ApplicationRecord
  include Postable
end
