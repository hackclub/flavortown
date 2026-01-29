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
require "test_helper"

class Post::ShipEventTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
