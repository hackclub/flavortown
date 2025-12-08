# == Schema Information
#
# Table name: post_devlogs
#
#  id                              :bigint           not null, primary key
#  body                            :string
#  duration_seconds                :integer
#  hackatime_projects_key_snapshot :text
#  hackatime_pulled_at             :datetime
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#
require "test_helper"

class Post::DevlogTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
