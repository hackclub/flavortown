# == Schema Information
#
# Table name: post_fire_events
# Database name: primary
#
#  id         :bigint           not null, primary key
#  body       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Post::FireEvent < ApplicationRecord
  include Postable
  has_paper_trail

  validates :body, presence: { message: "Message can't be blank" }
end
