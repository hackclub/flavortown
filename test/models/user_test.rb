# == Schema Information
#
# Table name: users
#
#  id             :bigint           not null, primary key
#  display_name   :string
#  email          :string
#  projects_count :integer
#  votes_count    :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
require "test_helper"

class UserTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
