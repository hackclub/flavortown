# == Schema Information
#
# Table name: project_memberships
#
#  id         :bigint           not null, primary key
#  role       :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  project_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_project_memberships_on_project_id              (project_id)
#  index_project_memberships_on_project_id_and_user_id  (project_id,user_id) UNIQUE
#  index_project_memberships_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class Project::MembershipTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
