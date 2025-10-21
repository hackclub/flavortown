# == Schema Information
#
# Table name: post_devlogs
#
#  id         :bigint           not null, primary key
#  body       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "test_helper"

class Post::DevlogTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
