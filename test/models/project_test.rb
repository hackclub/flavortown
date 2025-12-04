# == Schema Information
#
# Table name: projects
#
#  id                :bigint           not null, primary key
#  deleted_at        :datetime
#  demo_url          :text
#  description       :text
#  memberships_count :integer          default(0), not null
#  readme_url        :text
#  repo_url          :text
#  title             :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_projects_on_deleted_at  (deleted_at)
#
require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
