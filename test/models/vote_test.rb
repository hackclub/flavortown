# == Schema Information
#
# Table name: votes
#
#  id                 :bigint           not null, primary key
#  category           :integer          default("originality"), not null
#  demo_url_clicked   :boolean
#  reason             :text
#  repo_url_clicked   :boolean
#  score              :integer          not null
#  time_taken_to_vote :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  project_id         :bigint           not null
#  user_id            :bigint           not null
#
# Indexes
#
#  index_votes_on_project_id                           (project_id)
#  index_votes_on_user_id                              (user_id)
#  index_votes_on_user_id_and_project_id_and_category  (user_id,project_id,category) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class VoteTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
