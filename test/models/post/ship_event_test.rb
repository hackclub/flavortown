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
#  originality_median      :decimal(, )
#  originality_percentile  :decimal(, )
#  overall_percentile      :decimal(, )
#  overall_score           :decimal(, )
#  payout                  :float
#  storytelling_median     :decimal(, )
#  storytelling_percentile :decimal(, )
#  synced_at               :datetime
#  technical_median        :decimal(, )
#  technical_percentile    :decimal(, )
#  usability_median        :decimal(, )
#  usability_percentile    :decimal(, )
#  votes_count             :integer          default(0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
require "test_helper"

class Post::ShipEventTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
